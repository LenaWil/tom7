// Makes an SVG of the portmanteau graph of English.

#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <deque>

#include "util.h"
#include "timer.h"
#include "threadutil.h"
#include "arcfour.h"
#include "randutil.h"
#include "base/logging.h"
#include "textsvg.h"
#include "base/stringprintf.h"

using namespace std;

struct Word;
using smap = unordered_map<string, vector<Word *>>;
using sset = unordered_set<string>;

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

// Number of cells in word grid.
static constexpr int WWIDTH = 439;
static constexpr int WHEIGHT = 248;

struct Word {
  explicit Word(const string &s, int idx) : w(s), vector_idx(idx), idx(idx) {}
  const string w;
  // In word vector; never changes.
  const int vector_idx = 0;
  // In grid.
  int idx = 0;
  int X() const { return idx % WWIDTH; }
  int Y() const { return idx / WWIDTH; }
  sset prefixes;
  sset suffixes;
  // Outgoing edges.
  vector<Word *> neighbors;
  // Incoming edges.
  vector<Word *> rev_neighbors;
};

static void WriteData(const string &filename, const vector<Word> &words) {
  FILE *f = fopen(filename.c_str(), "wb");
  for (const Word &word : words) {
    fprintf(f, "%d %s\n", word.idx, word.w.c_str());
  }
  fclose(f);
  printf("Wrote %s.\n", filename.c_str());
}

static void WriteSVG(const string &filename, const vector<Word> &words) {
  // XXX Temporarily disabled to backfill Data.
  return;

  static constexpr double SVGWIDTH = WWIDTH * 10;
  static constexpr double SVGHEIGHT = WHEIGHT * 10;

  static constexpr double DOTSIZE = SVGWIDTH / WWIDTH;
  static constexpr double HALFDOT = DOTSIZE / 2.0;

  string svg = TextSVG::Header(SVGWIDTH, SVGHEIGHT);

  auto F = [](double d) {
    string s = StringPrintf("%f", d);
    while (!s.empty() && (s[s.size() - 1] == '0' || s[s.size() - 1] == '.')) {
      s.resize(s.size() - 1);
    }
    
    if (s.empty()) return string("0");
    else return s;
  };

  // Doesn't work to apply radius on <g> node, sadly.
  if (false) {
    svg += StringPrintf("<g fill-opacity=\"0.2\">\n");
    for (const Word &w : words) {
      svg += StringPrintf("<circle cx=\"%s\" cy=\"%s\" "
			  "r=\"%s\"/>\n",
			  F(w.X() * DOTSIZE + HALFDOT).c_str(),
			  F(w.Y() * DOTSIZE + HALFDOT).c_str(),
			  F(DOTSIZE * 0.4).c_str());
    }
    svg += "</g>\n";
  }

  // Color based on the shared string. Generate all the lines and put
  // them in the map with their shared string, so that we can then
  // make colors for those.
  map<string, vector<string>> lines;

  // Return the longest overlap from a to b.
  auto Shared = [](const string &a, const string &b) -> string {
    for (int i = std::min((int)a.size(), (int)b.size()); i >= 0; i--) {
      if (a.substr(a.size() - i, i) == b.substr(0, i)) {
	return b.substr(0, i);
      }
    }
    return "";
  };

  for (const Word &w : words) {
    for (const Word *other : w.neighbors) {
      lines[Shared(w.w, other->w)].push_back(
	  StringPrintf(R"(<line x1="%s" y1="%s" x2="%s" y2="%s"/>)" "\n",
		       F(w.X() * DOTSIZE + HALFDOT).c_str(),
		       F(w.Y() * DOTSIZE + HALFDOT).c_str(),
		       F(other->X() * DOTSIZE + HALFDOT).c_str(),
		       F(other->Y() * DOTSIZE + HALFDOT).c_str()));
    }
  }

  for (const auto &p : lines) {
    string s = p.first;
    // Get opacity from actual length?
    if (s.size() > 3) {
      s = s.substr(s.size() - 3, 3);
    }
    while (s.size() < 3) {
      s = "a" + s;
    }

    double r = (s[0] - 'a') / 26.0;
    double g = (s[1] - 'a') / 26.0;
    double b = (s[2] - 'a') / 26.0;
    string stroke = StringPrintf("%2x%2x%2x",
				 uint8(r * 255.0), uint8(g * 255.0), uint8(b * 255.0));
    svg += StringPrintf("<g stroke-width=\"0.2\" stroke=\"#%s\" stroke-opacity=\"0.5\">\n",
			stroke.c_str());
    for (const string &line : p.second) {
      svg += line;
    }
    svg += "</g>\n";
  }

  svg += TextSVG::Footer();

  printf("Grid SVG is %d bytes.\n", (int)svg.size());

  {
    FILE *f = fopen(filename.c_str(), "wb");
    CHECK(f != nullptr);
    fprintf(f, "%s\n", svg.c_str());
    fclose(f);
    printf("Wrote %s.\n", filename.c_str());
  }
}

int MakeGrid(ArcFour *rc, const vector<string> &dict) {
  vector<Word> words;
  // Such that perm[word.idx] == &word;
  vector<Word *> perm;
  int total_letters = 0;
  int max_length = 0;
  words.reserve(dict.size());
  perm.reserve(dict.size());
  for (const string &s : dict) {
    // Should strip.
    if (s.empty()) continue;
    for (char c : s) {
      if (c < 'a' || c > 'z') {
	printf("Bad: [%s]\n", s.c_str());
      }
    }
    words.push_back(Word{s, (int)words.size()});
    perm.push_back(&words[words.size() - 1]);
    total_letters += s.size();
    max_length = std::max((int)s.size(), max_length);
    // if (idx > 10000) break;
  }

  printf("Total size %d, max length %d\n", total_letters, max_length);

  smap fwd;
  smap bwd;
  vector<Word *> empty;
  auto Forward = [&empty, &fwd](const string &s) -> const vector<Word *> & {
    auto it = fwd.find(s);
    if (it == fwd.end()) return empty;
    else return it->second;
  };
  (void)Forward;

  auto Backward = [&empty, &bwd](const string &s) -> const vector<Word *> & {
    auto it = bwd.find(s);
    if (it == bwd.end()) return empty;
    else return it->second;
  };
  (void)Backward;

  for (Word &word : words) {
    for (int i = 1; i <= word.w.length(); i++) {
      string prefix = word.w.substr(0, i);
      string suffix = word.w.substr(i - 1, string::npos);
      word.prefixes.insert(prefix);
      word.suffixes.insert(suffix);
      fwd[prefix].push_back(&word);
      bwd[suffix].push_back(&word);
    }
  }
  printf("Built prefix/suffix map.\n");

  for (Word &w : words) {
    for (const string &suff : w.suffixes) {
      if (suff.size() > 4) {
	const vector<Word *> &neighbors = Forward(suff);
	for (Word *other : neighbors) {
	  w.neighbors.push_back(other);
	  other->rev_neighbors.push_back(&w);
	}
      }
    }
  }
  printf("Built graph.\n");

  WriteSVG("frame-0.svg", words);

  // Reduce energy.

  // Cost is geometric distance. (Square?)
  auto Distance = [](const Word &a, const Word &b) {
    double mx = a.X() - b.X();
    double my = a.Y() - b.Y();
    return sqrt((mx * mx) + (my * my));
  };

  // Starting energy. Could just define this as zero, I think, btw.
  double energy = 0.0;
  for (const Word &word : words) {
    for (const Word *other : word.neighbors) {
      energy += Distance(word, *other);
    }
  }
  printf("Starting energy %f.\n", energy);

  auto GetBothEnergy = [&Distance](const Word &word) {
    double energy = 0.0;
    for (const Word *other : word.neighbors) {
      energy += Distance(word, *other);
    }
    for (const Word *other : word.rev_neighbors) {
      energy += Distance(*other, word);
    }
    return energy;
  };

  for (int i = 0; i < words.size(); i++) {
    CHECK_EQ(words[i].vector_idx, i);
  }

  // Now, choose random pairs to swap.
  int swaps = 0;
  Timer running;

  int framenum = 1;
  auto TrySwap = [&rc, &words, &perm, &energy, &swaps, &running, &framenum,
		  &GetBothEnergy](int a, int b) {
    if (a != b) {
      int aidx = words[a].idx;
      int bidx = words[b].idx;
      // Current energy from outgoing and incoming edges.
      double oldeng = GetBothEnergy(words[a]) + GetBothEnergy(words[b]);
      // Trial swap.
      words[a].idx = bidx;
      words[b].idx = aidx;

      double neweng = GetBothEnergy(words[a]) + GetBothEnergy(words[b]);

      if (neweng < oldeng) {
	// Keep swap.
	perm[bidx] = &words[a];
	perm[aidx] = &words[b];

	swaps++;
	energy = energy - oldeng + neweng;
	if (swaps % 17000 == 0) {
	  WriteSVG(StringPrintf("frame-%d.svg", framenum), words);
	  WriteData(StringPrintf("frame-%d.txt", framenum), words);
	  framenum++;
	}
	  
	// Or if it's been a minute...
	if (running.MS() > 60 * 1000) {
	  WriteSVG(StringPrintf("grid.svg", swaps), words);
	  running.Start();
	}
      } else {
	// Undo.
	words[a].idx = aidx;
	words[b].idx = bidx;
      }
    }
  };

  for (;;) {
    Timer one_round;
    // These are indices into words, not the grid (we have to
    // read those from the idx field, and that's what we actually swap).
    for (int a = 0; a < words.size(); a++) {
      // int a = RandTo(rc, words.size());

      // Try the little neighborhood for micro-optimizations.
      for (int dx = -1; dx <= 1; dx++) {
	for (int dy = -1; dy <= 1; dy++) {
	  if (dx != 0 || dy != 0) {
	    int bx = words[a].X() + dx;
	    int by = words[a].Y() + dy;
	    if (bx >= 0 && bx < WWIDTH &&
		by >= 0 && by < WHEIGHT) {
	      int bidx = by * WWIDTH + bx;
	      CHECK(bidx >= 0);
	      // Even though it's in the grid, the last row is
	      // ragged. So check that it's actually in the
	      // vector!
	      if (bidx < perm.size()) {
		// Word at that pos.
		Word *bword = perm[bidx];
		CHECK(&words[bword->vector_idx] == bword);
		TrySwap(a, bword->vector_idx);
	      }
	    }
	  }
	}
      }

      for (int i = 0; i < 12; i++) {
	int b = RandTo(rc, words.size());
	TrySwap(a, b);
      }
    }

    printf("** One round in %.1fs **\n", one_round.MS() / 1000.0);
  }

  // WriteSVG("grid.svg", words);
  
  return 1;
}

int main () {
  vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  printf("%d words.\n", (int)dict.size());
  ArcFour rc("portmantout");
  
  MakeGrid(&rc, dict);

  return 0;
}
