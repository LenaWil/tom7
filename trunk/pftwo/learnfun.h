
#ifndef __LEARNFUN_H
#define __LEARNFUN_H

#include <vector>

#include "pftwo.h"

struct WeightedObjectives;
struct ObjectiveEnumerator;
struct Learnfun {
  // Argument must outlast object.
  explicit Learnfun(const vector<vector<uint8>> &memories);
  
  // Caller owns new-ly allocated pointer.
  WeightedObjectives *MakeWeighted();
  
 private:
  const vector<vector<uint8>> &memories;
  vector<vector<int>> objectives;

  void MakeObjectives(const vector<vector<uint8>> &memories);
  void GenerateNthSlices(int divisor, int num,
			 ObjectiveEnumerator *obj);
  void GenerateOccasional(int stride, int offsets, int num,
			  ObjectiveEnumerator *obj);
  
  void PrintAndSave(const vector<int> &ordering);
};

#endif
