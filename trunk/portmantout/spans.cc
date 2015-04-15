// Generate data for portmanteau explorer. Just works from the generated word
// and the dictionary, which means that it doesn't necessarily explain the
// portmantout the same way it was generated. (This is especially true if it
// is inefficient.)

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

#include "interval-tree.h"

using namespace std;

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

int main(int argc, char **argv) {
  if (argc != 2) {
    LOG(FATAL) << "Give a single filename on the command-line.";
  }
  const vector<string> p = Util::ReadFileToLines(argv[1]);
  CHECK_EQ(p.size(), 1) << "Expected a single line in the file.";
  string portmantout = std::move(p[0]);

  const vector<string> dict = Util::ReadFileToLines("wordlist.asc");

  printf("Dictionary is %d words and portmantout is %d chars.\n",
	 (int)dict.size(), (int)portmantout.size());

  // Coarse locking. Mutex protects the interval tree.
  std::mutex mutex;
  // The interval is the occurrence of the word within the portmantout.
  // The datum is the index of the word within the dictionary (and
  // backwards map). As we construct the tree we may remove unnecessary
  // intervals, but every character of the tree will be covered.
  IntervalTree<int, int> tree;
  // For each word index in dict, the vector of starting indices where
  // it can be found in the portmantout. We might remove unnecessary
  // occurrences, but each word will occur at least once.
  vector<vector<int>> backward;
  backward.resize(dict.size());
  Timer validation;
  ParallelComp(dict.size(),
	       [&portmantout, &dict, &mutex, &tree, &backward](int word_idx) {
     const string &w = dict[word_idx];
     int pos = portmantout.find(w, 0);
     CHECK(pos != string::npos) << "Word not found ever: " << w;
     while (pos != string::npos) {
       {
	 MutexLock ml(&mutex);
	 // PERF avoid inserting dumb ones.
	 tree.Insert(pos, pos + w.size(), word_idx);
	 backward[word_idx].push_back(pos);
       }

       pos = portmantout.find(w, pos + 1);
     }

     if (word_idx % 1000 == 0) {
       Printf("Did %d.\n", word_idx);
     }

  }, 8);

  Printf("Found the words.");

  // Output the tree as JSON.
  auto IdxJS = [](int i) -> string { return StringPrintf("%d", i); };
  auto TJS = [](int i) -> string { return StringPrintf("%d", i); };
  printf("%s\n", tree.ToJSON(IdxJS, TJS).c_str());

  double validation_ms = validation.MS();

  printf("PASSED: %.1fs\n", validation_ms / 1000.0);

  return 0;
}
