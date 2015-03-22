
#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <deque>

#include "base/logging.h"
#include "util.h"
#include "timer.h"
#include "arcfour.h"
#include "randutil.h"

#include "makeparticles.h"
#include "base/logging.h"

namespace {
struct Word;
using smap = unordered_map<string, vector<Word *>>;
using sset = unordered_set<string>;

struct Word {
  explicit Word(const string &s) : w(s) {}
  const string w;
  int accessibility = 0, exitability = 0, score = 0;
  int used = 0;
  sset prefixes, suffixes;
};
}

static constexpr bool SCORED_WORDS = false;

vector<string> MakeParticles(ArcFour *rc, const vector<string> &dict, bool verbose,
			     Trace *trace) {
  vector<Word> words;
  int total_letters = 0;
  int max_length = 0;
  words.reserve(dict.size());
  unordered_map<string, Word *> whole_word;
  for (const string &s : dict) {
    // Should strip.
    if (s.empty()) continue;
    for (char c : s) {
      if (c < 'a' || c > 'z') {
	printf("Bad: [%s]\n", s.c_str());
      }
    }
    words.push_back(Word{s});
    // XXX only works because we reserved above...
    whole_word[s] = &words[words.size() - 1];
    total_letters += s.size();
    max_length = std::max((int)s.size(), max_length);
  }

  if (verbose) printf("Total size %d, max length %d\n", total_letters, max_length);

  smap fwd;
  vector<Word *> empty;
  auto Forward = [&empty, &fwd](const string &s) -> vector<Word *> * {
    auto it = fwd.find(s);
    if (it == fwd.end()) return &empty;
    else return &it->second;
  };

  for (Word &word : words) {
    for (int i = 1; i <= word.w.length(); i++) {
      string prefix = word.w.substr(0, i);
      string suffix = word.w.substr(i - 1, string::npos);
      word.prefixes.insert(prefix);
      word.suffixes.insert(suffix);
      fwd[prefix].push_back(&word);
    }
  }
  if (verbose) printf("Built prefix map.\n");
  
  vector<Word *> sorted;
  sorted.reserve(words.size());
  for (Word &word : words) sorted.push_back(&word);

  if (SCORED_WORDS) {
    for (Word &word : words) {
      // If there's a (forward) path to a word, increment its accessibility.
      for (const string &suffix : word.suffixes) {
	vector<Word *> *nexts = Forward(suffix);
	word.exitability += nexts->size();
	for (Word *next : *nexts) {
	  next->accessibility++;
	}
      }
    }
    for (Word &word : words) {
      word.score = word.score + word.exitability;
    }

    std::sort(sorted.begin(), sorted.end(),
	      [](const Word *l, const Word *r) {
		return l->score < r->score;
	      });
  } else {
    Shuffle(rc, &sorted);
  }

  deque<Word*> todo(sorted.begin(), sorted.end());

  int already_substr = 0;
  string particle = "portmanteau";
  // Hopefully it's actually smaller than the whole dictionary...
  // particle.reserve(total_letters * 2);

  Round *round = nullptr;
  if (trace != nullptr) {
    // Typically in ~40k territory.
    trace->rounds.reserve(50000);
    trace->rounds.push_back(Round());
    round = &trace->rounds.back();
  }

  auto GetStartWord = [&todo]() -> Word * {
    while (!todo.empty()) {
      Word *w = todo.front();
      todo.pop_front();
      if (w->used == 0) return w;
    }
    LOG(FATAL) << "Uh, there are no more words.";
    return nullptr;
  };

  int num_done = 0;
  int num_left = words.size();

  Timer running;

  vector<string> particles;

  auto UseWord = [&num_left, &num_done](Word *w) {
    if (!w->used) {
      num_done++;
      num_left--;
    }
    w->used++;
  };

  Timer loop_timer;
  int particle_total = 0;
  while (num_left > 0) {
    // Mark words that are substrings.
    for (int st = std::max(0, (int)particle.size() - max_length * 2);
	 st < particle.size();
	 st++) {
      for (int len = 1; len <= particle.size() - st; len++) {
	auto it = whole_word.find(particle.substr(st, len));
	if (it != whole_word.end()) {
	  Word *maybe = it->second;
	  if (maybe->used == 0) {
	    already_substr++;
	    if (round != nullptr) {
	      round->covered.push_back(maybe->w);
	    }
	    UseWord(maybe);
	  }
	}
      }
    }

    for (int len = std::min(max_length, (int)particle.size()); len > 0; len--) {
      string suffix = particle.substr(particle.size() - len, string::npos);

      vector<Word *> *nexts = Forward(suffix);
      // printf("For suffx %s there were %d\n", suffix.c_str(), nexts->size());

      // Make sure the vector is just unused words.
      #if 1
      for (int i = 0; i < nexts->size(); i++) {
	Word *maybe = (*nexts)[i];
	if (maybe->used > 0) {
	  // We don't want to keep seeing this used word in the vector.
	  if (i != nexts->size() - 1) {
	    // Swap.
	    (*nexts)[i] = (*nexts)[nexts->size() - 1];
	    // Morally, do this, but it is now dead.
	    // nexts[nexts.size() - 1] = maybe;
	  }

	  // Then chop.
	  nexts->resize(nexts->size() - 1);

	  // And look again.
	  i--;
	}
      }
      #else
      {
	// Preserve order.
	vector<Word *> new_nexts;
	for (Word *maybe : *nexts) {
	  if (maybe->used == 0) {
	    new_nexts.push_back(maybe);
	  }
	}
	*nexts = std::move(new_nexts);
      }
      #endif

      // printf(" .. and then were %d\n", nexts->size());

      // There aren't any.
      int num_next = nexts->size();
      if (num_next == 0) continue;

      int next = (num_next == 1) ? 0 : RandTo(rc, num_next);
      Word *choice = (*nexts)[next];

      if (round != nullptr) {
	round->path.push_back(choice->w);
      }
      UseWord(choice);
      // This is maybe fastest way to add new suffix:

      // printf("%s (%s) + %s\n", particle.c_str(), suffix.c_str(), choice->w.c_str());
      particle.resize(particle.size() - suffix.size());
      particle += choice->w;

      if (verbose && num_done % 1000 == 0) {
	double per = loop_timer.MS() / num_done;
	printf("[%6d parts, %6dms per word, %6ds left, %6d skip] %s\n",
	       (int)particles.size(),
	       (int)per,
	       (int)((num_left * per) / 1000.0),
	       already_substr,
	       choice->w.c_str());
      }
      goto success;
    }

    if (verbose && particles.size() % 10000 == 0) {
      printf("There were no new continuations for [%s].. (%d done, %d left).\n"
	     "Already substr: %d\n"
	     "Took %.1fs\n",
	     particle.c_str(), num_done, num_left,
	     already_substr,
	     running.MS() / 1000.0);
    }
    particles.push_back(particle);
    particle_total += particle.size();

    if (num_left > 0) {
      Word *restart = GetStartWord();
      UseWord(restart);
      particle = restart->w;
      if (trace != nullptr) {
	trace->rounds.push_back(Round());
	round = &trace->rounds.back();
	round->path.push_back(restart->w);
      }
    }
    continue;

    success:;
  }
  particles.push_back(particle);
  particle_total += particle.size();

  if (verbose) {
    printf("Success! But I needed %d separate portmanteaus :(\n"
	   "And that was %d characters! (of %d, %.2f%% of the size)\n"
	   "I skipped %d words that were already substrs.\n"
	   "Took %.1fs\n",
	   (int)particles.size(),
	   particle_total, total_letters, (100.0 * particle_total / total_letters),
	   already_substr,
	   running.MS() / 1000.0);
  }

  return particles;
}
