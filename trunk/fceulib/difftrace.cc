
#include <vector>
#include <string>
#include <list>

#include "trace.h"

using namespace std;

using Trace = Traces::Trace;

static constexpr int MAX_HISTORY = 120;

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr, 
	    "Compares two trace files, given on the command line, "
	    "to show the first difference (if any).\n");
    return -1;
  }

  vector<Trace> left = Traces::ReadFromFile(argv[1]);
  fprintf(stderr, "Loaded %lld traces from %s.\n", left.size(), argv[1]);
  vector<Trace> right = Traces::ReadFromFile(argv[2]);
  fprintf(stderr, "Loaded %lld traces from %s.\n", right.size(), argv[2]);

  bool same = true;
  for (int i = 0; i < max(left.size(), right.size()); i++) {
    if (i >= left.size()) {
      printf("The right trace is longer (%lld vs. %lld) but they\n"
	     "are the same up to that point.\n", left.size(), right.size());
      same = false;
      break;
    } else if (i >= right.size()) {
      printf("The left trace is longer (%lld vs. %lld) but they\n"
	     "are the same up to that point.\n", left.size(), right.size());
      same = false;
      break;
    }

    const Trace &l = left[i], &r = right[i];
    if (!Traces::Equal(l, r)) {
      list<string> recent;
      int countleft = MAX_HISTORY;
      for (int j = i - 1; j > 0 && countleft > 0; j--) {
	recent.push_front(Traces::LineString(left[j]));
	countleft--;
      }
      printf("\n"
	     "---------------------------------------------\n"
	     "Recent:\n");
      for (const string &s : recent)
	printf("%s\n", s.c_str());

      printf("\n"
	     "=============================================\n");
      printf("At index %d, traces disagree.\n", i);
      printf("Diff:\n%s\n",
	     Traces::Difference(l, r).c_str());
      same = false;
      break;
    }
  }

  if (same) {
    printf("Well, I guess they are the same.\n");
    return 0;
  } else {
    return 1;
  }
}
