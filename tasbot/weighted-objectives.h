
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
  
  void SaveToFile(const std::string &filename) const;

  void SaveSVG(const vector< vector<uint8> > &memories,
	       const string &filename) const;

  size_t Size() const;
 
 private:
  WeightedObjectives();

  typedef std::map< std::vector<int>, double > Weighted;
  Weighted weighted;

  NOT_COPYABLE(WeightedObjectives);
};

#endif
