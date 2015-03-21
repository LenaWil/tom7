
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

using namespace std;

int main(int argc, char **argv) {
  if (argc != 2) {
    LOG(FATAL) << "Give a single filename on the command-line.";
  }
  const vector<string> p = Util::ReadFileToLines(argv[1]);
  CHECK_EQ(p.size(), 1) << "Expected a single line in the file.";
  string portmantout = std::move(p[0]);

  const vector<string> dict = Util::ReadFileToLines("wordlist.asc");

  Timer validation;
  for (const string &w : dict) {
    CHECK(portmantout.find(w) != string::npos) << "FAILED: ["
					       << portmantout
					       << "] / " << w;
  }
  double validation_ms = validation.MS();

  printf("PASSED: %.1fs\n", validation_ms / 1000.0);

  return 0;
}
