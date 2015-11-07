/*
  Classic learnfun algorithm for selecting weighted objectives,
  updated to use Emulator interface.
*/

#include "learnfun.h"

#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <map>

#include "pftwo.h"
#include "../fceulib/emulator.h"
#include "simplefm2.h"
#include "objective-enumerator.h"
#include "weighted-objectives.h"
#include "motifs.h"

// Not thread safe.
void Learnfun::PrintAndSave(const vector<int> &ordering) {
  printf("Size %d: ", (int)ordering.size());
  for (int i = 0; i < ordering.size(); i++) {
    printf("%d ", ordering[i]);
  }
  printf("\n");
  objectives.push_back(ordering);
}

  // With e.g. an divisor of 3, generate slices covering
  // the first third, middle third, and last third.
void Learnfun::GenerateNthSlices(int divisor, int num, 
				 ObjectiveEnumerator *oe) {
  const int onenth = memories.size() / divisor;
  for (int slicenum = 0; slicenum < divisor; slicenum++) {
    vector<int> look;
    int low = slicenum * onenth;
    for (int i = 0; i < onenth; i++) {
      look.push_back(low + i);
    }
    // printf("For slice %ld-%ld:\n", low, low + onenth - 1);
    for (int i = 0; i < num; i++) {
      oe->EnumerateFull(look,
			 [this](const vector<int> &ordering) {
			   PrintAndSave(ordering);
			 },
			 1, slicenum * 0xBEAD + i);
    }
  }
}

void Learnfun::GenerateOccasional(int stride, int offsets, int num,
				  ObjectiveEnumerator *oe) {
  for (int off = 0; off < offsets; off++) {
    vector<int> look;
    // Consider starting at various places throughout the first stide?
    for (int start = off; start < memories.size(); start += stride) {
      look.push_back(start);
    }
    // printf("For occasional @%d (every %d):\n", off, stride);
    for (int i = 0; i < num; i++) {
      oe->EnumerateFull(look,
			 [this](const vector<int> &ordering) {
			   PrintAndSave(ordering);
			 },
			 1, off * 0xF00D + i);
    }
  }
}

void Learnfun::MakeObjectives(const vector<vector<uint8>> &memories) {
  printf("Now generating objectives.\n");
  ObjectiveEnumerator oe(memories);
    
  // Going to generate a bunch of objective functions.
  // Some things will never violate the objective, like
  // [world number, stage number] or [score]. So generate
  // a handful of whole-game objectives.

  // TODO: In Mario, all 50 appear to be effectively the same
  // when graphed. Are they all equivalent, and should we be
  // accounting for that e.g. in weighting or deduplication?
  for (int i = 0; i < 50; i++) {  // was 10
    oe.EnumerateFullAll([this](const vector<int> &ordering) {
      PrintAndSave(ordering);
    }, 1, i);
  }

  // XXX Not sure how I feel about these, based on the
  // graphics. They are VERY noisy.

  // Next, generate objectives for each tenth of the game.
  GenerateNthSlices(10, 3, &oe);

  // And for each 1/100th.
  // GenerateNthSlices(100, 1, &oe);

  // Now, for individual frames spread throughout the
  // whole movie.
  // This one looks great.
  GenerateOccasional(100, 10, 10, &oe);
  // was 5,2

  GenerateOccasional(250, 10, 10, &oe);

  // This one looks okay; noisy at times.
  GenerateOccasional(1000, 10, 1, &oe);
}
  
Learnfun::Learnfun(const vector<vector<uint8>> &memories)
  : memories(memories) {
  printf("%d memories.\n", (int)memories.size());
  MakeObjectives(memories);
}

WeightedObjectives *Learnfun::MakeWeighted() {
  // Weight them.
  printf("There are %d objectives\n", (int)objectives.size());
  printf("And %d example memories\n", (int)memories.size());
  WeightedObjectives *weighted = new WeightedObjectives(objectives, memories);
  printf("And %d unique objectives\n", (int)weighted->Size());
  return weighted;
}
