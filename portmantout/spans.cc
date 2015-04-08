
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

  std::mutex mutex;
  IntervalTree<int, string> tree;

  Timer validation;
  ParallelComp(dict.size(),
	       [&portmantout, &mutex, &tree, &dict](int i) {
     const string &w = dict[i];
     int pos = portmantout.find(w, 0);
     CHECK(pos != string::npos) << "Word not found ever: " << w;
     while (pos != string::npos) {
       {
	 MutexLock ml(&mutex);
	 tree.Insert(pos, pos + w.size(), w);
       }
       pos = portmantout.find(w, pos + 1);
     }

     if (i % 1000 == 0) {
       Printf("Did %d.\n", i);
     }


	       }, 8);

  double validation_ms = validation.MS();

  printf("PASSED: %.1fs\n", validation_ms / 1000.0);

  return 0;
}
