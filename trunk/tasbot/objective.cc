
#include "objective.h"
#include "tasbot.h"

Objective::Objective(const vector< vector<uint8> > &mm) :
  memories(mm) {
  CHECK(!memories.empty());
  printf("Each memory is size %ld and there are %ld memories.\n",
	 memories[0].size(), memories.size());
}

static bool EqualOnPrefix(vector<uint8> mem1, vector<uint8> mem2,
			  const vector<int> &prefix) {
  for (int i = 0; i < prefix.size(); i++) {
    int p = prefix[i];
    // printf("  eop %d: %d vs %d\n", p, mem1[i], mem2[i]);
    if (mem1[p] != mem2[p])
      return false;
  }
  return true;
}

static bool LessEqual(vector<uint8> mem1, vector<uint8> mem2,
		      const vector<int> &order) {
  for (int i = 0; i < order.size(); i++) {
    int p = order[i];
    if (mem1[p] > mem2[p])
      return false;
    if (mem1[p] < mem2[p])
      return true;
  }
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

  for (int le = 0; le < left.size(); le++) {
    int c = left[le];
    bool less = false;

    // PERF I don't think this is actually necessary. Since this
    // function returns ALL candidates, the candidates are also all in
    // the remainder list. So, ignore anything that's already in the
    // prefix. (But it should get ignored below since it will
    // obviously be equal whenever EqualOnPrefix and it's in the
    // prefix.)
    for (int i = 0; i < prefix->size(); i++)
      if ((*prefix)[i] == c) {
	// printf("  skip %d in prefix\n", c);
	goto skip;
      }

    for (int lo = 0; lo < look.size() - 1; lo++) {
      int i = look[lo], j = look[lo + 1];
      // printf("  at lo %d. i=%d, j=%d\n", lo, i, j);
      if (EqualOnPrefix(memories[i], memories[j], *prefix)) {
	// printf("  (%d) equal on prefix #%d #%d\n", c, i, j);
	// We need to find at least one example where it is
	// strictly less, and none where it is greater.

	if (memories[i][c] > memories[j][c]) {
	  // It may be legal later, but not a candidate.
	  remain->push_back(c);
	  // printf("  skip %d because memories #%d and #%d have %d->%d\n",
	  // c, i, j, memories[i][c], memories[j][c]);
	  goto skip;
	}

	less = less || memories[i][c] < memories[j][c];
      }
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
  for (int lo = 0; lo < look.size() - 1; lo++) {
    int i = look[lo], j = look[lo + 1];
    const vector<uint8> &mem1 = memories[i], &mem2 = memories[j];
    if (!LessEqual(mem1, mem2, ordering)) {
      printf("Illegal ordering: [");
      for (int i = 0; i < ordering.size(); i++) {
	printf("%d ", ordering[i]);
      }
      printf("] at memories #%d and #%d:\n", i, j);

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
  printf("EPR: [");
  for (int i = 0; i < prefix->size(); i++) {
    printf("%d ", (*prefix)[i]);
  }
  printf("] left: [");
  for (int i = 0; i < left.size(); i++) {
    printf("%d ", left[i]);
  }
  printf("]\n");
#endif

  vector<int> candidates, remain;
  EnumeratePartial(look, prefix, left, &remain, &candidates);
  // If this is a maximal prefix, output it. Otherwise, extend.
  if (candidates.empty()) {
#   ifdef DEBUG
    CheckOrdering(look, memories, *prefix);
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
    } else {
      look.push_back(i);
    }
    look.push_back(i);
  }
  EnumerateFull(look, f);
}
