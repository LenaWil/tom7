
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

using namespace std;

struct Word;
using smap = unordered_map<string, vector<Word *>>;
using sset = unordered_set<string>;

struct Word {
  explicit Word(const string &s) : w(s) {}
  const string w;
  sset prefixes;
  sset suffixes;
};

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

int main () {
  vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  printf("%d words.\n", (int)dict.size());
  vector<string> particles = Util::ReadFileToLines("particles.txt");
  printf("%d particles.\n", (int)particles.size());
  ArcFour rc("portmantout");

  int total_letters = 0;
  for (const string &w : dict) {
    total_letters += w.size();
  }
  
  // Build a complete graph telling us how to efficiently get from the
  // source letter to destination, where both source and destination
  // are in [a-z]. We'll fill in the diagonal too, but we won't need
  // to use it.

  struct Path {
    Path() {}
    bool has = false;
    // Must start with src character and end with dst character.
    string word;
  };

  // Note that source letter will be ending a particle we're trying
  // to join, and dst will be beginning one.
  // matrix[src][dst]
  vector<vector<Path>> matrix(26, vector<Path>(26, Path()));

  auto SaveTable = [&matrix](const string &filename) {
    FILE *f = fopen(filename.c_str(), "wb");
    fprintf(f, "<!doctype html>\n"
	    "<style> td { padding: 0 4px } body { font: 13px Verdana } </style>\n"
	    "<table>");
    
    fprintf(f, "<tr><td>&nbsp;</td> ");
    for (int i = 0; i < 26; i++)
      fprintf(f, "<td>%c</td>", 'a' + i);
    fprintf(f, " </tr>\n");
    
    for (int src = 0; src < 26; src++) {
      fprintf(f, "<tr><td>%c</td> ", 'a' + src);
      for (int dst = 0; dst < 26; dst++) {
	const Path &p = matrix[src][dst];
	if (p.has) {
	  fprintf(f, "<td>%s</td>", p.word.c_str());
	} else {
	  fprintf(f, "<td>&mdash;</td>");
	}
      }
      fprintf(f, " </tr>\n");
    }

    fprintf(f, "</table>\n");
    fclose(f);
  };

  int entries = 0;
  for (const string &w : dict) {
    if (w.size() > 1) {
      int st = w[0] - 'a';
      int en = w[w.size() - 1] - 'a';
      if (st < 0 || st >= 26 ||
	  en < 0 || en >= 26) {
	printf("Bad: %s\n", w.c_str());
	abort();
      }

      // Is this a single-word path better than we already have?
      Path *p = &matrix[st][en];
      if (!p->has) {
	p->has = true;
	p->word = w;
	entries++;
      } else if (w.size() < p->word.size()) {
	p->word = w;
      }
    }
  }

  printf("We were able to trivially fill %d entries (%.2f%%)\n",
	 entries, (entries * 100.0) / (26 * 26));

  SaveTable("table-trivial.html");

  // Now iteratively fill.

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

  vector<Word> words;
  words.reserve(dict.size());
  for (const string &s : dict) words.push_back(Word{s});

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
  
  // Try two-word phrases.
  // Parallelize!
  for (const Word &word : words) {
    if (word.w.size() <= 1) continue;
    // PERF check if we already have the whole src covered?
    int st = word.w[0] - 'a';
    for (const string &suffix : word.suffixes) {
      for (const Word *other : Forward(suffix)) {
	int en = other->w[other->w.size() - 1] - 'a';
	Path *p = &matrix[st][en];
	int size = word.w.size() - suffix.size() + other->w.size();
	if (!p->has) {
	  p->has = true;
	  p->word = word.w.substr(0, word.w.size() - suffix.size()) + other->w;
	  entries++;
	} else if (size < p->word.size()) {
	  printf("[%s / %s / %s] Improved %s to ", 
		 word.w.c_str(), suffix.c_str(), other->w.c_str(),
		 p->word.c_str());
	  p->word = word.w.substr(0, word.w.size() - suffix.size()) + other->w;
	  printf("%s!\n", p->word.c_str());
	}
      }
    }
  }

  printf("With two word phrases, %d entries (%.2f%%)\n",
	 entries, (entries * 100.0) / (26 * 26));

  SaveTable("table-two.html");

  
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
  
  printf("All done! The portmantout is assembled, of size %d. (%.1f%% efficiency)\n",
	 (int)portmantout.size(),
	 (portmantout.size() * 100.0) / total_letters);
  {
    FILE *f = fopen("portmantout.txt", "wb");
    fprintf(f, "%s\n", portmantout.c_str());
    fclose(f);
  }

  return 0;
}
