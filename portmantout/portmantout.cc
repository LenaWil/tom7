
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

#include "makejoin.h"
#include "makeparticles.h"

using namespace std;

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);



int main () {
  const vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  printf("%d words.\n", (int)dict.size());
  const vector<vector<Path>> matrix = MakeJoin(dict);

  std::mutex best_m;
  int best_size = 999999999;

  auto OneThread = [&matrix, &dict, &best_m, &best_size](int thread_id) {
    ArcFour rc(StringPrintf("%d-Thread-%d", time(nullptr), thread_id));

    for (;;) {
      Timer one;
      vector<string> particles = MakeParticles(&rc, dict, true);

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

      // Validation.
      Timer validation;
      for (const string &w : dict) {
	CHECK(portmantout.find(w) != string::npos) << "FAILED: ["
						   << portmantout
						   << "] / " << w;
      }
      double validation_ms = validation.MS();

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

      Printf("%2d. %7d letters in [%.1fs] [val %.1fs] %s\n", thread_id, sz,
	     one.MS() / 1000.0, 
	     validation_ms / 1000.0,
	     nb.c_str());
    }
  };
  

  OneThread(0);

  /*
  static const int max_concurrency = 10;
  vector<std::thread> threads;
  threads.reserve(max_concurrency);
  for (int i = 0; i < max_concurrency; i++) {
    auto Thread = [&OneThread, i]() { OneThread(i); };
    threads.emplace_back(Thread);
  }
  // Won't ever actually finish.
  for (std::thread &t : threads) t.join();
  */

  return 0;
}
