/* A set of objective functions which may be weighted, and which may
   carry observations that allow them to be scored in absolute terms. */

#ifndef __WEIGHTED_OBJECTIVES_H
#define __WEIGHTED_OBJECTIVES_H

#include <map>
#include <vector>
#include <string>
#include <utility>

#include "pftwo.h"

// Constant collection of weighted objectives.
struct WeightedObjectives {
  // Use flat weights.
  explicit WeightedObjectives(const vector<vector<int>> &objs);
  // Use provided weights.
  explicit WeightedObjectives(vector<pair<vector<int>, double>> w_objs);
  // Weight using the example memories.
  WeightedObjectives(const vector<vector<int>> &objs,
		     const vector<vector<uint8>> &memories);
  static WeightedObjectives *LoadFromFile(const string &filename);
  
  void SaveToFile(const string &filename) const;

  size_t Size() const { return weighted.size(); }

  // Scoring function which is just the sum of the weights of
  // objectives where mem1 < mem2.
  double WeightedLess(const vector<uint8> &mem1,
                      const vector<uint8> &mem2) const;

  // Scoring function which is the count of objectives
  // where mem1 < mem2 minus the number where mem1 > mem2.
  double Evaluate(const vector<uint8> &mem1,
                  const vector<uint8> &mem2) const;

  // XXX weighted version, unnormalized version?
  const vector<pair<vector<int>, double>> &GetAll() const {
    return weighted;
  }

  const pair<vector<int>, double> &Get(int i) const {
    return weighted[i];
  }

  static const vector<uint8> Value(const vector<uint8> &memory,
				   const vector<int> &objective) {
    vector<uint8> ret;
    ret.resize(objective.size());
    for (int i = 0; i < objective.size(); i++)
      ret[i] = memory[objective[i]];
    return ret;
  }

 private:
  vector<pair<vector<int>, double>> weighted;
  NOT_COPYABLE(WeightedObjectives);
};

// Dynamic observations for computing "value fraction"-based metrics.
// From observing some states during exploration, we can compute an
// "absolute" score for a memory alone. (This is more flexible than
// simply a partial or total order because it can be used to compute
// relative scores.) This class separates the "accumulation" of
// observations from "committing" them, because:
//   - We expect to use this in a threaded context.
//   - New observations change the score, but it is often important
//     for correctness to have a consistent ordering (e.g. when
//     creating a data structure like a heap based on the scores).
//   - We want many threads to be able to "accumulate" observations
//     as they explore without blocking on an expensive operation.
struct Observations {
  // Observe a game state. Finishes quickly. Doesn't affect scoring
  // until Commit is called. Memory use is linear until that point.
  //
  // There is not much value to observing a huge number of states,
  // since we thin this to keep a sample of the observed range. It's
  // more important to observe a *variety* of states.
  // Observing is a little expensive.
  virtual void Accumulate(const vector<uint8> &memory) = 0;

  // Rebases values for GetNormalizedValue.
  virtual void Commit() = 0;

  // Get the (current) value of the memory in terms of observations.
  // The value is the unweighted average of the value of each objective
  // function relative to the values we've observed and committed; 1 means
  // that this is the higest value we've ever seen for that objective.
  // Does not observe the memory.
  virtual double GetNormalizedValue(const vector<uint8> &memory) = 0;

  // As GetNormalizedValue, but the weighted average of each fraction.
  // In [0, 1].
  virtual double GetWeightedValue(const vector<uint8> &memory) = 0;
  
  // As above, but rather than producing a single value for all objectives,
  // returns one value fraction per objective, in the same order they
  // appear within the WeightedObjectives object.
  // Weights are ignored. Does not observe the memory.
  virtual vector<double> GetNormalizedValues(const vector<uint8> &memory) = 0;

  // Construct concrete instances with different strategies. Caller
  // owns the new-ly created object.

  // Keep only a fixed-size sample of observations.
  // Currently this does not do anything special to keep the highest
  // value we ever saw, which may be bad if high values are rare.
  static Observations *SampleObservations(const WeightedObjectives &wo,
					  int max_samples);

  // This is very cheap (constant space and time), but treats each
  // objective component linearly. Keeps track of the maximum value
  // found for each component, and then treats this as its radix in a
  // mixed-base number. The normalized value is then just n / 1.0 in
  // that representation.
  static Observations *MixedBaseObservations(const WeightedObjectives &wo);
  
  // TODO: Some version where we keep only the maximum value ever seen,
  // then just treat the output as a fraction of that? Simpler than
  // MixedBase but are there any other advantages?
  // static Observations *MaxObservations(const WeightedObjectives &wo);

  virtual ~Observations();
 protected:
  // Argument must outlast object.
  explicit Observations(const WeightedObjectives &wo);

  const WeightedObjectives &wo;
};

#endif
