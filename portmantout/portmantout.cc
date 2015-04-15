
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
#include "base/stringprintf.h"
#include "textsvg.h"
#include "color-util.h"

#include "makejoin.h"
#include "makeparticles.h"
#include "image.h"

using namespace std;

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

static constexpr bool VALIDATE = false;
static constexpr bool JUST_ONE = false;
static constexpr bool TRACING = true;

static constexpr int WWIDTH = 439;
static constexpr int WHEIGHT = 248;
struct GridDot {
  GridDot() : idx(-1) {}
  GridDot(int idx) : idx(idx) {}
  int idx;
  int X() const { return idx % WWIDTH; }
  int Y() const { return idx / WWIDTH; }
};

static unordered_map<string, GridDot> LoadGrid(const string &filename) {
  unordered_map<string, GridDot> ret;
  const vector<string> lines = Util::ReadFileToLines(filename);
  Printf("%d grid lines.\n", (int)lines.size());
  for (string s : lines) {
    string numstr = Util::chop(s);
    string word = Util::losewhitel(s);
    int num = atoi(numstr.c_str());
    // Printf("%d [%s]\n", num, word.c_str());
    ret[word] = GridDot{num};
  }
  return ret;
}

static string F(double d) {
  string s = StringPrintf("%f", d);
  while (!s.empty() && (s[s.size() - 1] == '0' || s[s.size() - 1] == '.')) {
    s.resize(s.size() - 1);
  }
    
  if (s.empty()) return string("0");
  else return s;
};

static void WriteSVGFrames1(const unordered_map<string, GridDot> &grid,
			    const string &filebase, int num_frames, const Trace &trace) {
  int nontrivial = 0;
  for (const Round &round : trace.rounds) {
    if (round.path.size() > 1) {
      nontrivial++;
    }
  }
  Printf("There were %d nontrivial paths.\n", nontrivial);

  static constexpr double SVGWIDTH = WWIDTH * 10;
  static constexpr double SVGHEIGHT = WHEIGHT * 10;

  static constexpr double DOTSIZE = SVGWIDTH / WWIDTH;
  static constexpr double HALFDOT = DOTSIZE / 2.0;

  double framechunk = nontrivial / (double)num_frames;

  for (int frame = 0; frame < num_frames; frame++) {
    string svg = TextSVG::Header(SVGWIDTH, SVGHEIGHT);

    // Stuff before this gets very faded out.
    int old_idx = framechunk * frame;
    // Stuff before this (but also before 
    int this_idx = framechunk * (frame + 1);

    int nontrivial_idx = 0;
    for (int i = 0; i < trace.rounds.size() && i < this_idx; i++) {
      const Round &round = trace.rounds[i];
      if (round.path.size() > 1) {
	float r, g, b;
	ColorUtil::HSVToRGB(nontrivial_idx / (float)nontrivial, 1.0f, 0.75f,
			    &r, &g, &b);
	string rgb = StringPrintf("%02x%02x%02x", 
				  uint8(r * 255.0),
				  uint8(g * 255.0),
				  uint8(b * 255.0));
	double opacity = 
	  nontrivial_idx < old_idx ? 0.05 : 0.75;
	svg += StringPrintf("<polyline fill=\"none\" stroke=\"#%s\" opacity=\"%0.2f\" "
			    "stroke-width=\"0.5\" points=\"", rgb.c_str(), opacity);
	for (const string &word : round.path) {
	  auto it = grid.find(word);
	  CHECK(it != grid.end()) << "Word " << word << " not found in grid?";
	  int x = it->second.X(), y = it->second.Y();
	  svg += StringPrintf("%s,%s ",
			      F(x * DOTSIZE + HALFDOT).c_str(),
			      F(y * DOTSIZE + HALFDOT).c_str());
	}
	svg += "\"/>\n";
	nontrivial_idx++;
      }
    }
    svg += TextSVG::Footer();
    {
      string filename = StringPrintf("%s%d.svg", filebase.c_str(), frame);
      FILE *f = fopen(filename.c_str(), "wb");
      fprintf(f, "%s\n", svg.c_str());
      fclose(f);
      Printf("Wrote %s\n", filename.c_str());
    }
  }
}

// New version just dots.
static void WriteSVGFrames2(const unordered_map<string, GridDot> &grid,
			    const string &filebase, int num_frames, const Trace &trace) {
  int nontrivial = 0;
  for (const Round &round : trace.rounds) {
    if (round.path.size() > 0 /* XXX */) {
      nontrivial++;
    }
  }
  Printf("There were %d nontrivial paths.\n", nontrivial);

  static constexpr double SVGWIDTH = WWIDTH * 10;
  static constexpr double SVGHEIGHT = WHEIGHT * 10;

  static constexpr double DOTSIZE = SVGWIDTH / WWIDTH;
  static constexpr double HALFDOT = DOTSIZE / 2.0;

  double framechunk = nontrivial / (double)num_frames;

  for (int frame = 0; frame < num_frames; frame++) {
    string svg = TextSVG::Header(SVGWIDTH, SVGHEIGHT);

    // Stuff before this gets very faded out.
    int old_idx = framechunk * frame;
    // Stuff before this (but also before 
    int this_idx = framechunk * (frame + 1);

    int nontrivial_idx = 0;
    for (int i = 0; i < trace.rounds.size() && i < this_idx; i++) {
      const Round &round = trace.rounds[i];
      if (round.path.size() > 0 /* XXX */) {
	float r, g, b;
	ColorUtil::HSVToRGB(nontrivial_idx / (float)nontrivial, 1.0f, 1.0f,
			    &r, &g, &b);
	string rgb = StringPrintf("%02x%02x%02x", 
				  uint8(r * 255.0),
				  uint8(g * 255.0),
				  uint8(b * 255.0));
	double opacity = 
	  nontrivial_idx < old_idx ? 0.50 : 1.0;

	svg += StringPrintf("<g fill=\"#%s\" opacity=\"%0.2f\">\n",
			    rgb.c_str(), opacity);

	for (const string &word : round.path) {
	  auto it = grid.find(word);
	  CHECK(it != grid.end()) << "Word " << word << " not found in grid?";
	  int x = it->second.X(), y = it->second.Y();
	  svg += StringPrintf("<circle cx=\"%s\" cy=\"%s\" "
			      "r=\"%s\"/>\n",
			      F(x * DOTSIZE + HALFDOT).c_str(),
			      F(y * DOTSIZE + HALFDOT).c_str(),
			      F(DOTSIZE * 0.4).c_str());
	}
	svg += "</g>\n";

	svg += StringPrintf("<g fill=\"#000\" opacity=\"%.02f\">\n", opacity);
	for (const string &word : round.covered) {
	  auto it = grid.find(word);
	  CHECK(it != grid.end()) << "Word " << word << " not found in grid?";
	  int x = it->second.X(), y = it->second.Y();
	  svg += StringPrintf("<circle cx=\"%s\" cy=\"%s\" "
			      "r=\"%s\"/>\n",
			      F(x * DOTSIZE + HALFDOT).c_str(),
			      F(y * DOTSIZE + HALFDOT).c_str(),
			      F(DOTSIZE * 0.4).c_str());
	}
	svg += "</g>\n";

	nontrivial_idx++;
      }
    }
    svg += TextSVG::Footer();
    {
      string filename = StringPrintf("%s%d.svg", filebase.c_str(), frame);
      FILE *f = fopen(filename.c_str(), "wb");
      fprintf(f, "%s\n", svg.c_str());
      fclose(f);
      Printf("Wrote %s\n", filename.c_str());
    }
  }
}

static void WritePNGFrames(const unordered_map<string, GridDot> &grid,
			   const string &filebase, int num_frames, const Trace &trace) {
  int nontrivial = trace.rounds.size();

  static constexpr int PNGWIDTH = 1920;
  static constexpr int PNGHEIGHT = 1080;

  // Pixels
  static constexpr int DOTSIZE = 4;
  static constexpr int MARGINLEFT = (PNGWIDTH - (4 * WWIDTH)) >> 1;
  static constexpr int MARGINTOP = (PNGHEIGHT - (4 * WHEIGHT)) >> 1;

  double framechunk = nontrivial / (double)num_frames;

  for (int frame = 0; frame < num_frames; frame++) {
    ImageRGBA img{PNGWIDTH, PNGHEIGHT};
    for (uint8 &b : img.rgba) b = 0xFF;

    // Printf("%d.\n", (int)img.rgba.size());

    // Given top-left.
    auto DrawDot = [&img](int x, int y, float r, float g, float b, float a) {
      img.BlendPixelf(x + 0, y + 0, r, g, b, a * 0.25);
      img.BlendPixelf(x + 1, y + 0, r, g, b, a * 0.5);
      img.BlendPixelf(x + 2, y + 0, r, g, b, a * 0.5);
      img.BlendPixelf(x + 3, y + 0, r, g, b, a * 0.25);

      img.BlendPixelf(x + 0, y + 1, r, g, b, a * 0.5);
      img.BlendPixelf(x + 1, y + 1, r, g, b, a);
      img.BlendPixelf(x + 2, y + 1, r, g, b, a);
      img.BlendPixelf(x + 3, y + 1, r, g, b, a * 0.5);

      img.BlendPixelf(x + 0, y + 2, r, g, b, a * 0.5);
      img.BlendPixelf(x + 1, y + 2, r, g, b, a);
      img.BlendPixelf(x + 2, y + 2, r, g, b, a);
      img.BlendPixelf(x + 3, y + 2, r, g, b, a * 0.5);

      img.BlendPixelf(x + 0, y + 3, r, g, b, a * 0.25);
      img.BlendPixelf(x + 1, y + 3, r, g, b, a * 0.5);
      img.BlendPixelf(x + 2, y + 3, r, g, b, a * 0.5);
      img.BlendPixelf(x + 3, y + 3, r, g, b, a * 0.25);
    };

    // Stuff before this gets very faded out.
    int old_idx = framechunk * frame;
    // Stuff before this (but also before 
    int this_idx = framechunk * (frame + 1);

    int nontrivial_idx = 0;
    for (int i = 0; i < trace.rounds.size() && i < this_idx; i++) {
      const Round &round = trace.rounds[i];

      float r, g, b;
      ColorUtil::HSVToRGB(nontrivial_idx / (float)nontrivial, 1.0f, 1.0f,
			  &r, &g, &b);
      double opacity = nontrivial_idx < old_idx ? 0.75 : 1.0;

      for (const string &word : round.path) {
	auto it = grid.find(word);
	CHECK(it != grid.end()) << "Word " << word << " not found in grid?";
	int x = it->second.X(), y = it->second.Y();
	DrawDot(MARGINLEFT + x * DOTSIZE, MARGINTOP + y * DOTSIZE,
		r, g, b, opacity);
      }

      for (const string &word : round.covered) {
	auto it = grid.find(word);
	CHECK(it != grid.end()) << "Word " << word << " not found in grid?";
	int x = it->second.X(), y = it->second.Y();
	DrawDot(MARGINLEFT + x * DOTSIZE, MARGINTOP + y * DOTSIZE,
		0, 0, 0, opacity);
      }

      nontrivial_idx++;
    }

    string filename = StringPrintf("%s%d.png", filebase.c_str(), frame);
    img.Save(filename);
    Printf("Wrote %s\n", filename.c_str());
  }
}

int main() {
  // const vector<string> real_dict = Util::ReadFileToLines("wordlist.asc");
  // const vector<string> dict = Util::ReadFileToLines("testdict.asc");
  // const vector<vector<Path>> matrix = MakeJoin(real_dict);
  const vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  const vector<vector<Path>> matrix = MakeJoin(dict);
  const unordered_map<string, GridDot> grid = LoadGrid("frame-225.txt");
  printf("%d words.\n", (int)dict.size());

  #ifdef __MINGW32__
  if (!SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS)) {
    LOG(FATAL) << "Unable to go to BELOW_NORMAL priority.\n";
  }
  #endif

  const vector<string> p = Util::ReadFileToLines("portmantout.txt");
  CHECK_EQ(p.size(), 1) << "Expected a single line in the file.";
  string orig_portmantout = std::move(p[0]);

  std::mutex best_m;
  int best_size = orig_portmantout.size();
  printf("Existing portmantout is size %d.\n", (int)best_size);

  auto OneThread = [&matrix, &dict, &grid, &best_m, &best_size](int thread_id) {
    ArcFour rc(StringPrintf("%d-bThread-%d", time(nullptr), thread_id));

    for (int attempt = 0; true; attempt++) {
      Timer one;

      Trace trace;
      vector<string> particles = MakeParticles(&rc, dict, false, TRACING ? &trace : nullptr);

      if (TRACING) {
	WritePNGFrames(grid, StringPrintf("attempt%dt%d-", thread_id, attempt), 180, trace);
      }

      // Should maybe try this 10 times, take best?
      string portmantout = particles[0];
      for (int i = 1; i < particles.size(); i++) {
	CHECK(portmantout.size() > 0);
	const string &next = particles[i];
	CHECK(next.size() > 0);
	int src = portmantout[portmantout.size() - 1] - 'a';
	int dst = next[0] - 'a';
	CHECK(matrix[src][dst].has);
	const string &bridge = matrix[src][dst].word;

	// Chop one char.
	portmantout.resize(portmantout.size() - 1);
	portmantout += bridge;
	// And again.
	portmantout.resize(portmantout.size() - 1);
	portmantout += next;
      }


      string valstr;
      // Validation.
      if (VALIDATE) {
	Timer validation;
	for (const string &w : dict) {
	  CHECK(portmantout.find(w) != string::npos) << "FAILED: ["
						     << portmantout
						     << "] / " << w;
	}
	valstr = StringPrintf(" [val %.1fs]", validation.MS() / 1000.0);
      }

      int sz = (int)portmantout.size();

      string nb;
      {
	MutexLock ml(&best_m);
	nb = StringPrintf("best: %6d", best_size);
	if (sz < best_size) {
	  best_size = sz;
	  FILE *f = fopen("portmantout.txt", "wb");
	  fprintf(f, "%s\n", portmantout.c_str());
	  fclose(f);
	  nb = " * NEW BEST *";
	}
      }

      Printf("%2d. %7d letters in [%.1fs]%s  %s\n", thread_id, sz,
	     one.MS() / 1000.0, 
	     valstr.c_str(),
	     nb.c_str());

      if (true || JUST_ONE)
	return;
    }
  };

  if (JUST_ONE) {
    OneThread(0);
  } else {
    static const int max_concurrency = 4; //  11;
    vector<std::thread> threads;
    threads.reserve(max_concurrency);
    for (int i = 0; i < max_concurrency; i++) {
      auto Thread = [&OneThread, i]() { OneThread(i); };
      threads.emplace_back(Thread);
    }
    // Won't ever actually finish.
    for (std::thread &t : threads) t.join();
  }

  return 0;
}
