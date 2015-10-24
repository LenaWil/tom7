/*
  Classic learnfun algorithm for selecting weighted objectives,
  updated to use Emulator interface.
*/

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
#include "objective.h"
#include "weighted-objectives.h"
#include "motifs.h"

// Not thread safe.
struct Learnfun {

  void PrintAndSave(const vector<int> &ordering) {
    for (int i = 0; i < ordering.size(); i++) {
      printf("%d ", ordering[i]);
    }
    printf("\n");
    objectives.push_back(ordering);
  }

  // With e.g. an divisor of 3, generate slices covering
  // the first third, middle third, and last third.
  void GenerateNthSlices(int divisor, int num, 
			 const vector<vector<uint8>> &memories,
			 Objective *obj) {
    const int onenth = memories.size() / divisor;
    for (int slicenum = 0; slicenum < divisor; slicenum++) {
      vector<int> look;
      int low = slicenum * onenth;
      for (int i = 0; i < onenth; i++) {
	look.push_back(low + i);
      }
      // printf("For slice %ld-%ld:\n", low, low + onenth - 1);
      for (int i = 0; i < num; i++) {
	obj->EnumerateFull(look,
			   [this](const vector<int> &ordering) {
			     PrintAndSave(ordering);
			   },
			   1, slicenum * 0xBEAD + i);
      }
    }
  }

  void GenerateOccasional(int stride, int offsets, int num,
			  const vector<vector<uint8>> &memories,
			  Objective *obj) {
    for (int off = 0; off < offsets; off++) {
      vector<int> look;
      // Consider starting at various places throughout the first stide?
      for (int start = off; start < memories.size(); start += stride) {
	look.push_back(start);
      }
      // printf("For occasional @%d (every %d):\n", off, stride);
      for (int i = 0; i < num; i++) {
	obj->EnumerateFull(look,
 			   [this](const vector<int> &ordering) {
			     PrintAndSave(ordering);
			   },
			   1, off * 0xF00D + i);
      }
    }
  }

  void MakeObjectives(const vector<vector<uint8>> &memories) {
    printf("Now generating objectives.\n");
    Objective obj(memories);
    
    // Going to generate a bunch of objective functions.
    // Some things will never violate the objective, like
    // [world number, stage number] or [score]. So generate
    // a handful of whole-game objectives.

    // TODO: In Mario, all 50 appear to be effectively the same
    // when graphed. Are they all equivalent, and should we be
    // accounting for that e.g. in weighting or deduplication?
    for (int i = 0; i < 50; i++) // was 10
      obj.EnumerateFullAll([this](const vector<int> &ordering) {
			     PrintAndSave(ordering);
			   },
			   1, i);

    // XXX Not sure how I feel about these, based on the
    // graphics. They are VERY noisy.

    // Next, generate objectives for each tenth of the game.
    GenerateNthSlices(10, 3, memories, &obj);

    // And for each 1/100th.
    // GenerateNthSlices(100, 1, memories, &obj);

    // Now, for individual frames spread throughout the
    // whole movie.
    // This one looks great.
    GenerateOccasional(100, 10, 10, memories, &obj);
    // was 5,2

    GenerateOccasional(250, 10, 10, memories, &obj);

    // This one looks okay; noisy at times.
    GenerateOccasional(1000, 10, 1, memories, &obj);

  }
  
  Learnfun(const vector<vector<uint8>> &memories)
    : memories(memories) {
    MakeObjectives(memories);
  }

  vector<vector<uint8>> memories;
  vector<vector<int>> objectives;
  
  WeightedObjectives *MakeWeighted() {
    // Weight them.
    printf("There are %d objectives\n", (int)objectives.size());
    WeightedObjectives *weighted = new WeightedObjectives(objectives);
    printf("And %d example memories\n", (int)memories.size());
    weighted->WeightByExamples(memories);
    printf("And %d unique objectives\n", (int)weighted->Size());
    return weighted;
  }
};
