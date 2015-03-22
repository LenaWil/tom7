
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

static constexpr bool VALIDATE = false;
static constexpr bool JUST_ONE = false;

int main () {
  // const vector<string> real_dict = Util::ReadFileToLines("wordlist.asc");
  // const vector<string> dict = Util::ReadFileToLines("testdict.asc");
  // const vector<vector<Path>> matrix = MakeJoin(real_dict);
  const vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  const vector<vector<Path>> matrix = MakeJoin(dict);
  printf("%d words.\n", (int)dict.size());

  if (!SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS)) {
    LOG(FATAL) << "Unable to go to BELOW_NORMAL priority.\n";
  }

  const vector<string> p = Util::ReadFileToLines("portmantout.txt");
  CHECK_EQ(p.size(), 1) << "Expected a single line in the file.";
  string orig_portmantout = std::move(p[0]);

  std::mutex best_m;
  int best_size = orig_portmantout.size();
  printf("Existing portmantout is size %d.\n", (int)best_size);

  auto OneThread = [&matrix, &dict, &best_m, &best_size](int thread_id) {
    ArcFour rc(StringPrintf("%d-bThread-%d", time(nullptr), thread_id));

    for (;;) {
      Timer one;

      Trace trace;
      vector<string> particles = MakeParticles(&rc, dict, false, &trace);

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

      if (JUST_ONE)
	return;
    }
  };

  if (JUST_ONE) {
    OneThread(0);
  } else {
    static const int max_concurrency = 11;
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
