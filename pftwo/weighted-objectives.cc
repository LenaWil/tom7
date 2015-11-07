
#include "weighted-objectives.h"

#include <algorithm>
#include <set>
#include <string>
#include <iostream>
#include <sstream>
#include <utility>
#include <vector>

#include <mutex>

#include "pftwo.h"
#include "../cc-lib/arcfour.h"
#include "util.h"

#include "../cc-lib/threadutil.h"
#include "../cc-lib/randutil.h"

using namespace std;

// WeightedObjectives::WeightedObjectives() {}

WeightedObjectives::WeightedObjectives(const vector<vector<int>> &objs) {
  weighted.clear();
  weighted.reserve(objs.size());
  for (const vector<int> &v : objs) {
    weighted.push_back({v, 1.0});
  }
}

WeightedObjectives::WeightedObjectives(vector<pair<vector<int>, double>>
				       w_objs) :
  weighted(w_objs) {
}

static string ObjectiveToString(const vector<int> &obj) {
  string s;
  for (int i = 0; i < obj.size(); i++) {
    char d[64] = {0};
    sprintf(d, "%s%d", (i ? " " : ""), obj[i]);
    s += d;
  }
  return s;
}

WeightedObjectives *
WeightedObjectives::LoadFromFile(const string &filename) {
  vector<pair<vector<int>, double>> wo;
  vector<string> lines = Util::ReadFileToLines(filename);
  wo.reserve(lines.size());
  for (int i = 0; i < lines.size(); i++) {
    string line = lines[i];
    Util::losewhitel(line);
    if (!line.empty() && !Util::startswith(line, "#")) {
      stringstream ss(line, stringstream::in);
      double d;
      ss >> d;
      vector<int> locs;
      while (!ss.eof()) {
	int i;
	ss >> i;
	locs.push_back(i);
      }
      wo.push_back({std::move(locs), d});
    }
  }

  return new WeightedObjectives(wo);
}
  
void WeightedObjectives::SaveToFile(const string &filename) const {
  string out;
  for (const auto &row : weighted) {
    if (row.second > 0.0) {
      const vector<int> &obj = row.first;
      double d = row.second;
      out += StringPrintf("%f %s\n", d, ObjectiveToString(obj).c_str());
    }
  }
  Util::WriteFile(filename, out);
  printf("Saved weighted objectives to %s\n", filename.c_str());
}

static bool LessObjective(const vector<uint8> &mem1, 
			  const vector<uint8> &mem2,
			  const vector<int> &order) {
  for (int i = 0; i < order.size(); i++) {
    int p = order[i];
    if (mem1[p] > mem2[p])
      return false;
    if (mem1[p] < mem2[p])
      return true;
  }

  // Equal.
  return false;
}

// Order 1 means mem1 < mem2, -1 means mem1 > mem2, 0 means equal.
// (note this is backwards from strcmp. Think of if like a multiplier
// for the weight.)
static int Order(const vector<uint8> &mem1, 
		 const vector<uint8> &mem2,
		 const vector<int> &order) {
  for (int i = 0; i < order.size(); i++) {
    int p = order[i];
    if (mem1[p] > mem2[p])
      return -1;
    if (mem1[p] < mem2[p])
      return 1;
  }

  // Equal.
  return 0;
}

double WeightedObjectives::WeightedLess(const vector<uint8> &mem1,
					const vector<uint8> &mem2) const {
  double score = 0.0;
  for (const auto &wobj : weighted) {
    const vector<int> &objective = wobj.first;
    const double weight = wobj.second;
    if (LessObjective(mem1, mem2, objective))
      score += weight;
  }
  CHECK(score >= 0);
  return score;
}

double WeightedObjectives::Evaluate(const vector<uint8> &mem1,
				    const vector<uint8> &mem2) const {
  double score = 0.0;
  for (const auto &wobj : weighted) {
    const vector<int> &objective = wobj.first;
    const double weight = wobj.second;
    switch (Order(mem1, mem2, objective)) {
    case -1: score -= weight; break;
    case 1: score += weight; break;
    case 0:
    default:;
    }
  }
  return score;
}

namespace {
struct SampleObservations : public Observations {
  SampleObservations(const WeightedObjectives &wo, int max_samples) :
    Observations(wo), max_samples(max_samples), watermark(wo.Size(), 0),
    acc_values(wo.Size(), vector<pair<uint32, vector<uint8>>>{}) {

  }
  
  void Accumulate(const vector<uint8> &memory) override {
    MutexLock ml(&acc_mutex);
    for (int i = 0; i < wo.Size(); i++) {
      const pair<vector<int>, double> &obj = wo.Get(i);
      // In order to keep a fair random sample, we assign each
      // observation a random number when we add it. PERF: A heap
      // would maybe be better here to avoid re-sorting, but
      // this keeps the space usage bounded at least.
      const uint32 key = Rand32(&rc);
      if (key < watermark[i]) continue;

      // OK, we'll keep the sample. Compute its value.
      
      vector<uint8> value = WeightedObjectives::Value(memory, obj.first);
      
      acc_values[i].push_back({key, std::move(value)});
    }
#if 0
    for (Weighted::iterator it = weighted.begin();
	 it != weighted.end(); ++it) {
      const vector<int> &obj = it->first;
      Info *info = it->second;
      info->observations.resize(info->observations.size() + 1);
      vector<uint8> *cur = &info->observations.back();
      cur->reserve(obj.size());

      for (int i = 0; i < obj.size(); i++) {
	cur->push_back(memory[obj[i]]);
      }

      info->is_sorted = false;

      // Maybe should just keep the unique values? Otherwise
      // lower_bound is doing something kind of funny when there
      // are lots of the same value...
    }
#endif
  }

  // Maximum samples to keep in our permanent observations.
  const int max_samples;
  
  // Parallel to the weighted objectives. Just discard a sample if
  // its key is smaller than the value in here.
  vector<uint32> watermark;
  
  ArcFour rc{"sample"};
  // Parallel to the weighted objectives. Queue of keys (less than the
  // watermark) along with the value. These will be considered for the
  // next commit.
  vector<vector<pair<uint32, vector<uint8>>>> acc_values;
  std::mutex acc_mutex;
};
}  // namespace
  
static vector<uint8> GetValues(const vector<uint8> &mem,
			       const vector<int> &objective) {
  vector<uint8> out;
  out.resize(objective.size());
  for (int i = 0; i < objective.size(); i++) {
    CHECK(objective[i] < mem.size());
    out[i] = mem[objective[i]];
  }
  return out;
}

static vector<vector<uint8>>
GetUniqueValues(const vector<vector<uint8 >> &memories,
		const vector<int> &objective) {
  set<vector<uint8>> values;
  for (int i = 0; i < memories.size(); i++) {
    values.insert(GetValues(memories[i], objective));
  }
    
  vector<vector<uint8>> uvalues;
  uvalues.insert(uvalues.begin(), values.begin(), values.end());
  return uvalues;
}

// Find the index of the vector now within the values
// array, which is sorted and unique.
static inline int GetValueIndex(const vector<vector<uint8>> &values,
				const vector<uint8> &now) {
  return lower_bound(values.begin(), values.end(), now) - values.begin();
}

static inline double GetValueFrac(const vector<vector<uint8>> &values,
				  const vector<uint8> &now) {
  int idx = GetValueIndex(values, now);
  // -1, since it can never be the size itself?
  // and what should the value be if values is empty or singleton?
  return (double)idx / values.size();
}

#if 0
// XXX implement
double SampleObservations::GetNormalizedValue(const vector<uint8> &mem) {
  double sum = 0.0;

  for (Weighted::iterator it = weighted.begin(); it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    Info *info = &*it->second;
    
    vector<uint8> cur;
    cur.reserve(obj.size());
    for (int i = 0; i < obj.size(); i++) {
      cur.push_back(mem[obj[i]]);
    }

    sum += GetValueFrac(info->GetObservations(), cur);
  }

  sum /= (double)weighted.size();
  return sum;
}

vector<double> WeightedObjectives::
SampleObservations(const vector<uint8> &mem) {
  vector<double> out;
  for (Weighted::iterator it = weighted.begin(); it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    Info *info = &*it->second;
    
    vector<uint8> cur;
    cur.reserve(obj.size());
    for (int i = 0; i < obj.size(); i++) {
      cur.push_back(mem[obj[i]]);
    }

    out.push_back(GetValueFrac(info->GetObservations(), cur));
  }

  return out;
}
#endif

static vector<pair<vector<int>, double>>
  WeightByExamples(const vector<vector<int>> &objs,
		   const vector<vector<uint8>> &memories) {
  vector<pair<vector<int>, double>> out;
  out.reserve(objs.size());
  for (const vector<int> &obj : objs) {
    // All the distinct values this objective takes on, in order.
    vector<vector<uint8>> values = GetUniqueValues(memories, obj);

    // Sum of deltas is just very last - very first.
    CHECK(memories.size() > 0);
    double score_end =
      GetValueFrac(values, GetValues(memories[memories.size() - 1], obj));
    double score_begin = 
      GetValueFrac(values, GetValues(memories[0], obj));
    CHECK(score_end >= 0 && score_end <= 1);
    CHECK(score_begin >= 0 && score_begin <= 1);
    double score = score_end - score_begin;

    if (score <= 0.0) {
      printf("Bad objective lost more than gained: %f / %s\n",
	     score, ObjectiveToString(obj).c_str());
      // XXX delete it?
      out.push_back({obj, 0.0});
    } else {
      out.push_back({obj, score});
    }
  }
  return out;
}

WeightedObjectives::WeightedObjectives(const vector<vector<int>> &objs,
				       const vector<vector<uint8>> &memories) :
  WeightedObjectives(WeightByExamples(objs, memories)) { }

#if 0
struct WeightedObjectives::Info {
  explicit Info(double w) : weight(w), is_sorted(true) {}
  double weight;

  // Sorted, ascending.
  double is_sorted;  
  vector<vector<uint8>> observations;

  const vector<vector<uint8>> &GetObservations() {
    if (!is_sorted) {
      std::sort(observations.begin(), observations.end());
      is_sorted = true;
    }

    return observations;
  }
};
#endif

