
#include "weighted-objectives.h"

#include <algorithm>
#include <set>
#include <string>
#include <iostream>
#include <sstream>
#include <utility>
#include <vector>

#include "pftwo.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/textsvg.h"
#include "util.h"

using namespace std;

struct WeightedObjectives::Info {
  explicit Info(double w) : weight(w), is_sorted(true) {}
  double weight;

  // Sorted, ascending.
  double is_sorted;  
  vector< vector<uint8> > observations;

  const vector< vector<uint8> > &GetObservations() {
    if (!is_sorted) {
      std::sort(observations.begin(), observations.end());
      is_sorted = true;
    }

    return observations;
  }
};

WeightedObjectives::WeightedObjectives() {}

WeightedObjectives::WeightedObjectives(const vector< vector<int> > &objs) {
  for (int i = 0; i < objs.size(); i++) {
    weighted[objs[i]] = new Info(1.0);
  }
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
  WeightedObjectives *wo = new WeightedObjectives;
  vector<string> lines = Util::ReadFileToLines(filename);
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
      wo->weighted.insert(make_pair(locs, new Info(d)));
    }
  }

  return wo;
}

vector< pair<const vector<int> *, double> > WeightedObjectives::GetAll() const {
  vector< pair<const vector<int> *, double> > v;
  for (Weighted::const_iterator it = weighted.begin(); 
       it != weighted.end(); ++it) {
    v.push_back(make_pair(&it->first, it->second->weight));
  }
  return v;
}
  
void WeightedObjectives::SaveToFile(const string &filename) const {
  string out;
  for (Weighted::const_iterator it = weighted.begin(); 
       it != weighted.end(); ++it) {
    if (it->second->weight > 0) {
      const vector<int> &obj = it->first;
      const Info &info = *it->second;
      out += StringPrintf("%f %s\n", info.weight,
			  ObjectiveToString(obj).c_str());
    }
  }
  Util::WriteFile(filename, out);
  printf("Saved weighted objectives to %s\n", filename.c_str());
}

size_t WeightedObjectives::Size() const {
  return weighted.size();
}

void WeightedObjectives::Observe(const vector<uint8> &memory) {
  // PERF Currently, we just keep a sorted vector for each objective's
  // value at each observation. This is not very efficient. Worse, it
  // may have the undesirable effect that a particular state's value
  // can change (arbitrarily) with future observations, even just by
  // observing states we've already seen again (changes mass
  // distribution).
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
  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &objective = it->first;
    const double weight = it->second->weight;
    if (LessObjective(mem1, mem2, objective))
      score += weight;
  }
  CHECK(score >= 0);
  return score;
}

double WeightedObjectives::Evaluate(const vector<uint8> &mem1,
				    const vector<uint8> &mem2) const {
  double score = 0.0;
  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &objective = it->first;
    const double weight = it->second->weight;
    switch (Order(mem1, mem2, objective)) {
    case -1: score -= weight; break;
    case 1: score += weight; break;
    case 0:
    default:;
    }
  }
  return score;
}

#if 0
// XXX can probably simplify this, but should probably just remove it.
double WeightedObjectives::BuggyEvaluate(const vector<uint8> &mem1,
					 const vector<uint8> &mem2) const {
  double score = 0.0;
  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &objective = it->first;
    const double weight = it->second->weight;
    switch (Order(mem1, mem2, objective)) {
      // XXX bug!!
    case -1: score -= weight; // FALLTHROUGH
      case 1: score += weight;
      case 0:
      default:;
    }
  }
  return score;
}
#endif

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

static vector< vector<uint8> >
GetUniqueValues(const vector< vector<uint8 > > &memories,
		const vector<int> &objective) {
  set< vector<uint8> > values;
  for (int i = 0; i < memories.size(); i++) {
    values.insert(GetValues(memories[i], objective));
  }
    
  vector< vector<uint8> > uvalues;
  uvalues.insert(uvalues.begin(), values.begin(), values.end());
  return uvalues;
}

// Find the index of the vector now within the values
// array, which is sorted and unique.
static inline int GetValueIndex(const vector< vector<uint8> > &values,
				const vector<uint8> &now) {
  return lower_bound(values.begin(), values.end(), now) - values.begin();
}

static inline double GetValueFrac(const vector< vector<uint8> > &values,
				  const vector<uint8> &now) {
  int idx = GetValueIndex(values, now);
  // -1, since it can never be the size itself?
  // and what should the value be if values is empty or singleton?
  return (double)idx / values.size();
}

double WeightedObjectives::GetNormalizedValue(const vector<uint8> &mem) {
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
GetNormalizedValues(const vector<uint8> &mem) {
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

void WeightedObjectives::WeightByExamples(const vector< vector<uint8> >
					  &memories) {
  for (Weighted::iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    Info *info = it->second;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);


    // Sum of deltas is just very last - very first.
    CHECK(memories.size() > 0);
    double score_end =
      GetValueFrac(values, GetValues(memories[memories.size() - 1], obj));
    double score_begin = 
      GetValueFrac(values, GetValues(memories[0], obj));
    CHECK(score_end >= 0 && score_end <= 1);
    CHECK(score_begin >= 0 && score_begin <= 1);
    double score = score_end - score_begin;

    /*
    int lastvaluefrac = 0.0;
    for (int i = 0; i < memories.size(); i++) {
      vector<uint8> now = GetValues(memories[i], obj);
      double valuefrac = GetValueFrac(values, now);
      CHECK(valuefrac >= 0);
      CHECK(valuefrac <= 1);
      score += (valuefrac - lastvaluefrac);
      lastvaluefrac = valuefrac;
    }
    */

    if (score <= 0.0) {
      printf("Bad objective lost more than gained: %f / %s\n",
	     score, ObjectiveToString(obj).c_str());
      info->weight = 0.0;
    } else {
      info->weight = score;
    }
  }
}
