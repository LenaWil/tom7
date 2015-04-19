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
#include "interval-tree-json.h"

using namespace std;

std::mutex print_mutex;
#define Printf(fmt, ...) do {			\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

#define EPrintf(fmt, ...) do {			\
  MutexLock Printf_ml(&print_mutex);		\
  fprintf(stderr, fmt, ##__VA_ARGS__);		\
  } while (0);

int main(int argc, char **argv) {
  ArcFour rc("spans");
  if (argc != 3) {
    LOG(FATAL) << "./spans.exe dict.txt portmantout.txt";
  }
  vector<string> dict = Util::ReadFileToLines(argv[1]);
  CHECK(!dict.empty()) << "Dictionary had nothing in it?";
  Shuffle(&rc, &dict);

  const vector<string> p = Util::ReadFileToLines(argv[2]);
  CHECK_EQ(p.size(), 1) << "Expected a single line in the file " << argv[2];
  string portmantout = std::move(p[0]);

  EPrintf("Dictionary is %d words and portmantout is %d chars.\n",
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
  Timer find_timer;
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
       }
       backward[word_idx].push_back(pos);

       pos = portmantout.find(w, pos + 1);
     }

     if (word_idx % 1000 == 0) {
       EPrintf("Did %d.\n", word_idx);
     }

  }, 8);
  double find_ms = find_timer.MS();
  EPrintf("Found the words.\n");

  // vector<vector<int>> 

  // Output the tree as JSON.
  EPrintf("Write to JSON...");
  auto IdxJS = [](const int &i) -> string { return std::to_string(i); };
  auto TJS = [](const int &i) -> string { return std::to_string(i); };
  Timer json_timer;
  IntervalTreeJSON<int, int> itjson{tree, IdxJS, TJS, 25};
  const string json = itjson.ToCompactJSON([](const int &l, const int &r){
    return l - r;
  });
  double json_ms = json_timer.MS();
  EPrintf(" %d bytes.\n", (int)json.size());
  Util::WriteFile("spanstest.js",
		  StringPrintf("var spans=%s;\n", json.c_str()));
  Util::WriteFile("portmantout.js",
		  StringPrintf("var portmantout='%s';\n",
			       portmantout.c_str()));
  EPrintf("Written.\n");

  EPrintf("FIND: %.1fs\n"
	  "JSON: %.1fs\n", 
	  find_ms / 1000.0,
	  json_ms / 1000.0);

  return 0;
}
