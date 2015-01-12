
#include <vector>
#include <string>

#include "trace.h"

using namespace std;

using Trace = Traces::Trace;

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
  
  for (int i = 0; i < max(left.size(), right.size()); i++) {
    if (i >= left.size()) {
      printf("The right trace is longer (%lld vs. %lld) but they\n"
	     "are the same up to that point.\n", left.size(), right.size());
      break;
    } else if (i >= right.size()) {
      printf("The left trace is longer (%lld vs. %lld) but they\n"
	     "are the same up to that point.\n", left.size(), right.size());
      break;
    }

    const Trace &l = left[i], &r = right[i];
    if (!Traces::Equal(l, r)) {
      printf("At index %d, traces disagree.\n", i);
      // XXX show the diff, duh
      break;
    }
  }

  return 0;
}
