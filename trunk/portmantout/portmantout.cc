
#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>

#include "util.h"
#include "timer.h"
#include "threadutil.h"

using namespace std;

struct Word;
using smap = unordered_map<string, vector<Word *>>;
using sset = unordered_set<string>;

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

int main () {
  vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  printf("%d words.\n", (int)dict.size());
  
  vector<Word> words;
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
  }

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
    // XXX Prefix and suffix should of course be nonempty, but should
    // we include the entire word? I mean, in the case of 'a' we kind
    // of have to?
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
  double op_ms = onepass.MS();
  printf("Took %fms\n", op_ms);

  ParallelComp(words.size(), [&words](int i) {
    words[i].score = words[i].accessibility + words[i].exitability;
  }, 8);

  vector<const Word *> sorted;
  for (const Word &word : words) sorted.push_back(&word);
  std::sort(sorted.begin(), sorted.end(),
	    [](const Word *l, const Word *r) {
	      return l->score < r->score;
	    });
  for (const Word *word : sorted) {
    printf("%d -> %s -> %d\n", word->accessibility, word->w.c_str(), word->exitability);
  }

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
