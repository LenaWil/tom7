
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
// (note this is backwards from strcmp. Think of it like a multiplier
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

namespace {
struct SampleObservations : public Observations {
  SampleObservations(const WeightedObjectives &wo, int max_samples) :
    Observations(wo), max_samples(max_samples), watermark(wo.Size(), 0),
    obs_values(wo.Size(), vector<pair<uint32, vector<uint8>>>{}),
    acc_values(wo.Size(), vector<pair<uint32, vector<uint8>>>{}) {

  }

  static bool CompareByKeyDesc(const pair<uint32, vector<uint8>> &a,
			       const pair<uint32, vector<uint8>> &b) {
    // In case of key ties (should be extremely rare), use the vectors
    // to ensure stability.
    if (a.first == b.first)
      return a.second < b.second;
    // Descending by key.
    return b.first < a.first;
  }

  static bool CompareByValue(const pair<uint32, vector<uint8>> &a,
			     const pair<uint32, vector<uint8>> &b) {
    // Should be no need to break ties by key, because keys are not
    // used when sorted this way (except to re-sort by key).
    return a.second < b.second;
  }

  // Same as GetValueIndex, but when the observations are paired with
  // the random key.
  static inline
  int GetKValueIndex(const vector<pair<uint32, vector<uint8>>> &values,
		     const vector<uint8> &now) {
    return lower_bound(values.begin(), values.end(), make_pair(0, now),
		       CompareByValue) -
      values.begin();
  }

  static inline
  double GetKValueFrac(const vector<pair<uint32, vector<uint8>>> &values,
		       const vector<uint8> &now) {
    int idx = GetKValueIndex(values, now);
    // -1, since it can never be the size itself?
    // and what should the value be if values is empty or singleton?
    return (double)idx / values.size();
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
      if (key < watermark[i]) {
	watermark_discarded++;
	continue;
      }

      // OK, we'll keep the sample. Compute its value.
      
      vector<uint8> value = WeightedObjectives::Value(memory, obj.first);
      
      acc_values[i].push_back({key, std::move(value)});
    }
  }

  // Clear the accumulator queue, moving the highest-keyed values
  // into the observations, sorting, and updating the watermark.
  void Commit() override {
    MutexLock mlo(&obs_mutex);

    CHECK_EQ(wo.Size(), acc_values.size());
    CHECK_EQ(wo.Size(), obs_values.size());
    CHECK_EQ(wo.Size(), watermark.size());

    int64 accumulated = 0ll, dropped = 0ll, discarded = 0ll, in_mem = 0ll;
    for (int i = 0; i < wo.Size(); i++) {
      acc_mutex.lock();
      discarded += watermark_discarded;
      watermark_discarded = 0ll;
      vector<pair<uint32, vector<uint8>>> &av = acc_values[i];
      // For example, all new accumulations were instantly
      // discarded for having keys too small.
      if (av.empty()) {
	acc_mutex.unlock();
	continue;
      }

      accumulated += av.size();
      
      vector<pair<uint32, vector<uint8>>> &ov = obs_values[i];

      // Move into observations.
      ov.reserve(ov.size() + av.size());
      for (auto &v : av) ov.push_back(std::move(v));
      av.clear();
      acc_mutex.unlock();
      
      // Now sort by key (descending) so that we can take only the largest.
      // We only need to do this once the vector is full.
      if (ov.size() > max_samples) {
	dropped += ov.size() - max_samples;
	std::sort(ov.begin(), ov.end(), CompareByKeyDesc);
	ov.resize(max_samples);
	watermark[i] = ov.back().first;
      }

      // Now put it in sorted order by value (ascending).
      std::sort(ov.begin(), ov.end(), CompareByValue);

      in_mem += ov.size();
    }

    printf("Committed %lld, dropped %lld, discarded %lld. Have %lld\n",
	   accumulated, dropped, discarded, in_mem);
  }

  vector<double> GetNormalizedValues(const vector<uint8> &mem) override {
    vector<double> vals;
    vals.reserve(wo.Size());
    {
      MutexLock mlo(&obs_mutex);
      for (int i = 0; i < wo.Size(); i++) {
	const vector<int> &obj = wo.Get(i).first;
	vector<uint8> cur = WeightedObjectives::Value(mem, obj);
	vals.push_back(GetKValueFrac(obs_values[i], cur));
      }
    }

    return vals;
  }

  double GetNormalizedValue(const vector<uint8> &mem) override {
    double sum = 0.0;

    {
      MutexLock mlo(&obs_mutex);
      for (int i = 0; i < wo.Size(); i++) {
	const vector<int> &obj = wo.Get(i).first;
	vector<uint8> cur = WeightedObjectives::Value(mem, obj);
	sum += GetKValueFrac(obs_values[i], cur);
      }
    }
      
    sum /= (double)wo.Size();
    return sum;
  }

  double GetWeightedValue(const vector<uint8> &mem) override {
    double numer = 0.0;
    double total_weight = 0.0;
    
    {
      MutexLock mlo(&obs_mutex);
      for (int i = 0; i < wo.Size(); i++) {
	const vector<int> &obj = wo.Get(i).first;
	const double weight = wo.Get(i).second;
	vector<uint8> cur = WeightedObjectives::Value(mem, obj);
	numer += GetKValueFrac(obs_values[i], cur) * weight;
	total_weight += weight;
      }
    }
      
    return numer / total_weight;
  }
  
  // Maximum samples to keep in our permanent observations.
  const int max_samples;

  // Parallel to the weighted objectives. Just discard a sample if
  // its key is smaller than the value in here.
  // Once we have max_samples for the obs_values vector (which should
  // happen simultaneously for all objectives), this is the smallest
  // key in the vector. Before that, it is 0 because we want to keep
  // all samples.
  vector<uint32> watermark;
  int64 watermark_discarded = 0;
  
  // Parallel to the weighted objectives. Sample keys and observed
  // value, sorted by value. No more than max_samples in each vector;
  // keys are all greater than or equal to watermark.
  vector<vector<pair<uint32, vector<uint8>>>> obs_values;
 
  ArcFour rc{"sample"};
  // Parallel to the weighted objectives. Queue of keys (less than the
  // watermark) along with the value. These will be considered for the
  // next commit.
  vector<vector<pair<uint32, vector<uint8>>>> acc_values;
  std::mutex obs_mutex, acc_mutex;
};


struct MixedBaseObservations : public Observations {
  MixedBaseObservations(const WeightedObjectives &wo) :
    Observations(wo), acc_maxbytes(wo.Size()) {
    for (int i = 0; i < wo.Size(); i++) {
      const vector<int> &obj = wo.Get(i).first;
      // Everything is max byte 0 to start.
      acc_maxbytes[i].resize(obj.size(), 0);
      // acc_maxbytes.push_back(vector<uint8>{obj.size(), 0});
    }
    obs_maxbytes = acc_maxbytes;
  }
  
  void Accumulate(const vector<uint8> &memory) override {
    MutexLock ml(&acc_mutex);
    for (int i = 0; i < wo.Size(); i++) {
      const vector<int> &obj = wo.Get(i).first;
      // Now just do pointwise max.
      for (int j = 0; j < obj.size(); j++) {
	const uint8 val = memory[obj[j]];
	uint8 &old = acc_maxbytes[i][j];
	if (val > old) old = val;
      }
    }
  }

  void Commit() override {
    MutexLock mlo(&obs_mutex);
    MutexLock mla(&acc_mutex);
    obs_maxbytes = acc_maxbytes;
  }

  vector<double> GetNormalizedValues(const vector<uint8> &mem) override {
    vector<double> vals;
    vals.resize(wo.Size());
    {
      MutexLock mlo(&obs_mutex);
      for (int i = 0; i < wo.Size(); i++) {
	const vector<int> &obj = wo.Get(i).first;
	// PERF inline
	vector<uint8> cur = WeightedObjectives::Value(mem, obj);

	// Let's say the max byte observed for each position is
	// a, b, c, d, ..., y, z.
	// The largest number that can be represented given our
	// current understanding of the base would be to place the
	// max byte in each position; then we have
	//
	// 1.0 = (z-1) + (y-1)*z + (x-1)*(z*y) + ...
	//       (b-1) * (c*d*...*y*z) + (a-1) * (b*c*d*...*y*z)
	//     = a*b*c*d*...*y*z - 1
	//
	// Since this involves factorials it gets big awfully
	// quickly. For now, doubles maybe give us the sensitivity
	// we need. (Otherwise: We can compute this as an arbitrary
	// precision int, as long as we can then do division?)
	double multiplier = 1.0;
	double seen = 0.0;
	for (int j = cur.size() - 1; j >= 0; j--) {
	  seen += cur[j] * multiplier;
	  // Radix is largest byte seen but plus one.
	  multiplier *= ((int)obs_maxbytes[i][j] + 1);
	}

	vals[i] = seen / multiplier;
	// This can probably happen for reasonable inputs. Might
	// need some arbitrary precision thing here.
	CHECK(!isnan(vals[i])) << "\n" << seen << " " << multiplier;
	CHECK(vals[i] >= 0.0);
      }
    }

    return vals;
  }

  // PERF the following two could maybe be faster by inlining
  // the above (not creating the vectors).
  double GetNormalizedValue(const vector<uint8> &mem) override {
    double sum = 0.0;
    for (const double val : GetNormalizedValues(mem))
      sum += val;
      
    sum /= (double)wo.Size();
    return sum;
  }

  double GetWeightedValue(const vector<uint8> &mem) override {
    double numer = 0.0;
    double total_weight = 0.0;

    const vector<double> vals = GetNormalizedValues(mem);
    CHECK(vals.size() > 0);
    for (int i = 0; i < vals.size(); i++) {
      const double weight = wo.Get(i).second;
      CHECK(vals[i] >= 0.0);
      CHECK(weight >= 0.0);
      CHECK(!isnan(vals[i]));
      numer += weight * vals[i];
      total_weight += weight;
    }

    CHECK(!isnan(numer));
    CHECK(!isnan(total_weight));
    CHECK(total_weight != 0);
    return numer / total_weight;
  }
  
  vector<vector<uint8>> obs_maxbytes, acc_maxbytes;
  std::mutex obs_mutex, acc_mutex;
};

}  // namespace

Observations::Observations(const WeightedObjectives &wo) : wo(wo) {}
Observations::~Observations() {}

Observations *Observations::SampleObservations(const WeightedObjectives &wo,
					       int max_samples) {
  return new ::SampleObservations(wo, max_samples);
}

Observations *Observations::MixedBaseObservations(
    const WeightedObjectives &wo) {
  return new ::MixedBaseObservations(wo);
}

#if 0

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
