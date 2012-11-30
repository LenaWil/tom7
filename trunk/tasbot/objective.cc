
#include "objective.h"
#include "tasbot.h"

// Self-check output.
#define DEBUG_OBJECTIVE 1
#define VERBOSE_OBJECTIVE 1

#define VPRINTF if (0) printf

Objective::Objective(const vector< vector<uint8> > &mm) :
  memories(mm) {
  CHECK(!memories.empty());
  printf("Each memory is size %ld and there are %ld memories.\n",
	 memories[0].size(), memories.size());
}

static bool EqualOnPrefix(const vector<uint8> &mem1, 
			  const vector<uint8> &mem2,
			  const vector<int> &prefix) {
#if 0
  // Go in reverse, because we extend to the right, so new
  // failures happen towards the end.
  // (this is actually slower)
  for (int i = prefix.size() - 1; i >= 0; i--) {
    int p = prefix[i];
    // printf("  eop %d: %d vs %d\n", p, mem1[i], mem2[i]);
    if (mem1[p] != mem2[p]) {
      VPRINTF("Disequal at %d\n", p);
      return false;
    }
  }
  return true;
#else
  for (int i = 0; i < prefix.size(); i++) {
    int p = prefix[i];
    // printf("  eop %d: %d vs %d\n", p, mem1[i], mem2[i]);
    if (mem1[p] != mem2[p]) {
      VPRINTF("Disequal at %d\n", p);
      return false;
    }
  }
  return true;
#endif
}

static bool LessEqual(const vector<uint8> &mem1, 
		      const vector<uint8> &mem2,
		      const vector<int> &order) {
  for (int i = 0; i < order.size(); i++) {
    int p = order[i];
    VPRINTF("  %d: %d vs %d ", p, mem1[p], mem2[p]);
    if (mem1[p] > mem2[p])
      return false;
    if (mem1[p] < mem2[p]) {
      VPRINTF(" ok\n");
      return true;
    }
  }
  VPRINTF(" end\n");
  return true;
}

void Objective::EnumeratePartial(const vector<int> &look,
				 vector<int> *prefix,
				 const vector<int> &left,
				 vector<int> *remain,
				 vector<int> *candidates) {
  // First step is to remove any candidates from left that
  // are not interesting here. For c to be interesting, there
  // must be some i,j within look where i < j and memory[i][c] <
  // memory[j][c] and memory[i] == memory[j] for the prefix,
  // and memory[i][c] is always <= memory[j][c] for all i,j
  // in look where memory[i] == memory[j] for the prefix.
  // We only need to check consecutive memories; a distant
  // counterexample means that there is an adjacent
  // counterexample somewhere in between.

  // Cache this.
  // indices lo in look where look[lo] and look[lo + 1]
  // are equal on the prefix
  vector<int> lequal;
  lequal.reserve(look.size() - 1);
  for (int lo = 0; lo < look.size() - 1; lo++) {
    int i = look[lo], j = look[lo + 1];
    if (EqualOnPrefix(memories[i], memories[j], *prefix)) {
      lequal.push_back(lo);
    }
  }

  for (int le = 0; le < left.size(); le++) {
    int c = left[le];
    bool less = false;

    // PERF I don't think this is actually necessary. Since this
    // function returns ALL candidates, the candidates are also all in
    // the remainder list. So, ignore anything that's already in the
    // prefix. (But it should get ignored below since it will
    // obviously be equal whenever EqualOnPrefix and it's in the
    // prefix.)
    for (int i = 0; i < prefix->size(); i++) {
      if ((*prefix)[i] == c) {
	// printf("  skip %d in prefix\n", c);
	goto skip;
      }
    }

    for (int lo = 0; lo < lequal.size(); lo++) {
      int i = look[lo], j = look[lo + 1];
      // printf("  at lo %d. i=%d, j=%d\n", lo, i, j);
      if (memories[i][c] > memories[j][c]) {
	// It may be legal later, but not a candidate.
	remain->push_back(c);
	// printf("  skip %d because memories #%d and #%d have %d->%d\n",
	// c, i, j, memories[i][c], memories[j][c]);
	goto skip;
      }

      less = less || memories[i][c] < memories[j][c];
    }

    if (less) {
      candidates->push_back(c);
      remain->push_back(c);
    } else {
      // Always equal. Filtered out and can never become
      // interesting.
      // printf("  %d is always equal; filtered.\n", c);
    }

    skip:;
  }
}

static void CheckOrdering(const vector<int> &look,
			  const vector< vector<uint8> > &memories,
			  const vector<int> &ordering) {
  VPRINTF("CheckOrdering [");
  for (int i = 0; i < ordering.size(); i++) {
    VPRINTF("%d ", ordering[i]);
  }
  VPRINTF("]...\n");

  for (int lo = 0; lo < look.size() - 1; lo++) {
    int ii = look[lo], jj = look[lo + 1];
    const vector<uint8> &mem1 = memories[ii];
    const vector<uint8> &mem2 = memories[jj];

    if (mem1 == mem2) {
      VPRINTF("Memories exactly the same? %d %d\n", ii, jj);
      continue;
    } else if (EqualOnPrefix(mem1, mem2, ordering)) {
      // printf("equal. %d %d\n", ii, jj);
      // abort();
      continue;
    }

    VPRINTF("mem #%d vs #%d\n", ii, jj);
    if (!LessEqual(mem1, mem2, ordering)) {
      printf("Illegal ordering: [");
      for (int i = 0; i < ordering.size(); i++) {
	printf("%d ", ordering[i]);
      }
      printf("] at memories #%d and #%d:\n", ii, jj);

      for (int i = 0; i < ordering.size(); i++) {
	int p = ordering[i];
	printf ("%d is %d vs %d\n", p, mem1[p], mem2[p]);
      }

      abort();
    }
    
  }
  
}

void Objective::EnumeratePartialRec(const vector<int> &look,
				    vector<int> *prefix,
				    const vector<int> &left,
				    void (*f)(const vector<int> &ordering)) {
#if 0
  VPRINTF("EPR: [");
  for (int i = 0; i < prefix->size(); i++) {
    VPRINTF("%d ", (*prefix)[i]);
  }
  VPRINTF("] left: [");
  for (int i = 0; i < left.size(); i++) {
    VPRINTF("%d ", left[i]);
  }
  VPRINTF("]\n");
#endif

  vector<int> candidates, remain;
  EnumeratePartial(look, prefix, left, &remain, &candidates);
  // If this is a maximal prefix, output it. Otherwise, extend.
  if (candidates.empty()) {
#   ifdef DEBUG_OBJECTIVE
    CheckOrdering(look, memories, *prefix);
    // printf("Checked:\n");
#   endif
    (*f)(*prefix);
  } else {
    prefix->resize(prefix->size() + 1);
    for (int i = 0; i < candidates.size(); i++) {
      (*prefix)[prefix->size() - 1] = candidates[i];
      EnumeratePartialRec(look, prefix, remain, f);
    }
    prefix->resize(prefix->size() - 1);
  }
}

void Objective::EnumerateFull(const vector<int> &look,
			      void (*f)(const vector<int> &ordering)) {
  vector<int> prefix, left;
  for (int i = 0; i < memories[0].size(); i++) {
    left.push_back(i);
  }
  EnumeratePartialRec(look, &prefix, left, f);
}

void Objective::EnumerateFullAll(void (*f)(const vector<int> &ordering)) {
  vector<int> look;
  for (int i = 0; i < memories.size(); i++) {
    if (i > 0 && memories[i] == memories[i - 1]) {
      printf("Duplicate memory at %d-%d\n", i - 1, i);
      // PERF don't include it!
      // look.push_back(i);
    } else {
      look.push_back(i);
    }
  }
  EnumerateFull(look, f);
}
