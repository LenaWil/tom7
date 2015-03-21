#include <unordered_map>
#include <unordered_set>

#include "makejoin.h"
#include "base/logging.h"

namespace {
struct Word;
using smap = unordered_map<string, vector<Word *>>;
using sset = unordered_set<string>;

struct Word {
  explicit Word(const string &s) : w(s) {}
  const string w;
  sset prefixes;
  sset suffixes;
};
}  // namespace

vector<vector<Path>> MakeJoin(const vector<string> &dict) {
  vector<vector<Path>> matrix(26, vector<Path>(26, Path()));

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

  CHECK(entries == 26 * 26) << "Maybe need three-word phrases :(";

  return matrix;
}
