
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

using namespace std;

struct Word;
using smap = unordered_map<string, vector<Word *>>;
using sset = unordered_set<string>;

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

struct Word {
  explicit Word(const string &s) : w(s) {}
  const string w;
  int used = 0;
  int accessibility = 0;
  int exitability = 0;
  int score = 0;
  sset prefixes;
  sset suffixes;
};

int Attempt (ArcFour *rc, const vector<string> &dict) {
  vector<Word> words;
  int total_letters = 0;
  int max_length = 0;
  words.reserve(dict.size());
  for (const string &s : dict) {
    // Should strip.
    if (s.empty()) continue;
    for (char c : s) {
      if (c < 'a' || c > 'z') {
	printf("Bad: [%s]\n", s.c_str());
      }
    }
    words.push_back(Word{s});
    total_letters += s.size();
    max_length = std::max((int)s.size(), max_length);
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

  auto Backward = [&empty, &bwd](const string &s) -> const vector<Word *> & {
    auto it = bwd.find(s);
    if (it == bwd.end()) return empty;
    else return it->second;
  };

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

  Timer onepass;
  for (Word &word : words) {
    word.accessibility = 0;
    word.exitability = 0;
  }
  for (Word &word : words) {
    // If there's a (forward) path to a word, increment its accessibility.
    for (const string &suffix : word.suffixes) {
      const vector<Word *> &nexts = Forward(suffix);
      word.exitability += nexts.size();
      for (Word *next : nexts) {
	next->accessibility++;
      }
    }
  }
  for (Word &word : words) {
    word.score = word.score + word.exitability;
  }

  double op_ms = onepass.MS();
  printf("Scoring took %fms\n", op_ms);
  
  vector<Word *> sorted;
  sorted.reserve(words.size());
  for (Word &word : words) sorted.push_back(&word);
  std::sort(sorted.begin(), sorted.end(),
	    [](const Word *l, const Word *r) {
	      return l->score < r->score;
	    });

  deque<Word*> todo(sorted.begin(), sorted.end());

  // int already_substr = 0;
  string portmantout = "portmanteau";
  // Hopefully it's actually smaller than the whole dictionary...
  portmantout.reserve(total_letters * 2);
  // Okay, now do them from hardest to easiest.

  int num_done = 0;
  int num_left = words.size();

  Timer running;
  while (num_left > 0) {
    // Mark words that are substrings?

    for (int len = std::min(max_length, (int)portmantout.size()); len > 0; len--) {
      string suffix = portmantout.substr(portmantout.size() - len, string::npos);
      // printf("Try suffix [%s].\n", suffix.c_str());
      const vector<Word *> &nexts = Forward(suffix);
      for (Word *maybe : nexts) {
	if (maybe->used == 0) {
	  num_done++;
	  num_left--;
	  maybe->used++;
	  // This is maybe fastest way to add new suffix:
	  portmantout.resize(portmantout.size() - suffix.size());
	  portmantout += maybe->w;
	  // XXX remove it from exits?
	  // printf("%s\n", maybe->w.c_str());
	  goto success;
	}
      }
    }

    printf("There were no new continuations for [%s].. (%d done, %d left).\n"
	   "Took %.1fs\n", portmantout.c_str(), num_done, num_left,
	   running.MS() / 1000.0);
    return 0;

    success:;
  }

  printf("Success: %s\n"
	 "Took %.1fs\n",
	 portmantout.c_str(),
	 running.MS() / 1000.0);
  return 1;

#if 0
  for (int idx = 0; idx < sorted.size(); idx++) {


    if (idx % 100 == 0) {
      printf("Portmantout is %d chars, working on [%s].c_str()");

    }
    const string &thisword = sorted[i]->w;
    // If the word is already in the portmantout, then we are done.
    if (portmantout.find(thisword) == string::npos) {
      already_substr++;
    }

  }
#endif
}

int main () {
  vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  printf("%d words.\n", (int)dict.size());
  ArcFour rc("portmantout");
  
  Attempt(&rc, dict);

#if 0
  vector<const Word *> sorted;
  for (const Word &word : words) sorted.push_back(&word);
  std::sort(sorted.begin(), sorted.end(),
	    [](const Word *l, const Word *r) {
	      return l->score < r->score;
	    });
  for (const Word *word : sorted) {
    printf("%d -> %s -> %d\n", word->accessibility, word->w.c_str(), word->exitability);
  }
#endif

  return 0;
}

#if 0
  int starts[26] = {};
  int ends[26] = {};

  for (const string &s : dict) {
    // Should strip.
    if (s.empty()) continue;
    int st = s[0] - 'a';
    int en = s[s.size() - 1] - 'a';
    if (st < 0 || st >= 26 ||
	en < 0 || en >= 26) {
      printf("Bad: [%s]\n", s.c_str());
    } else {
      starts[st]++;
      ends[en]++;
    }
  }

  for (int i = 0; i < 26; i++) {
    printf("%6d   %c %6d\n", starts[i], 'a' + i, ends[i]);
  }
#endif
