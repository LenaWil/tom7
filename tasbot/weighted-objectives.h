
#ifndef __WEIGHTED_OBJECTIVES_H
#define __WEIGHTED_OBJECTIVES_H

#include <map>
#include <vector>
#include <string>

#include "tasbot.h"
#include "fceu/types.h"

struct WeightedObjectives {
  explicit WeightedObjectives(const std::vector< vector<int> > &objs);
  static WeightedObjectives *LoadFromFile(const std::string &filename);
  
  void WeightByExamples(const vector< vector<uint8> > &memories);
			
  void SaveToFile(const std::string &filename) const;

  void SaveSVG(const vector< vector<uint8> > &memories,
	       const string &filename) const;

  size_t Size() const;

  // Scoring function which is just the count of the number
  // of objectives where mem1 < mem2.
  double GetNumLess(const vector<uint8> &mem1,
		    const vector<uint8> &mem2) const;

  // Scoring function which is the count of objectives
  // that where mem1 < mem2 minus the number where mem1 > mem2.
  double Evaluate(const vector<uint8> &mem1,
		  const vector<uint8> &mem2) const;
 
 private:
  WeightedObjectives();

  typedef std::map< std::vector<int>, double > Weighted;
  Weighted weighted;

  NOT_COPYABLE(WeightedObjectives);
};

#endif
