
#include "weighted-objectives.h"

#include <algorithm>
#include <set>
#include <string>
#include <iostream>
#include <sstream>

#include "tasbot.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/textsvg.h"
#include "util.h"

using namespace std;

struct WeightedObjectives::Info {
  explicit Info(double w) : weight(w) {}
  double weight;

  // Sorted, ascending.
  vector< vector<uint8> > observations;
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
    stringstream ss(lines[i], stringstream::in);
    double d;
    ss >> d;
    vector<int> locs;
    while (!ss.eof()) {
      int i;
      ss >> i;
      locs.push_back(i);
    }

    printf("GOT: %f | %s\n", d, ObjectiveToString(locs).c_str());
    wo->weighted.insert(make_pair(locs, new Info(d)));
  }

  return wo;
}
  
void WeightedObjectives::SaveToFile(const string &filename) const {
  string out;
  for (Weighted::const_iterator it = weighted.begin(); 
       it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    out += StringPrintf("%f %s\n", it->second,
			ObjectiveToString(obj).c_str());
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

    // PERF sorted insert is O(n/2); dunno how std::sort
    // behaves on nearly-sorted vectors.
    std::sort(info->observations.begin(), info->observations.end());

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


double WeightedObjectives::GetNumLess(const vector<uint8> &mem1,
				      const vector<uint8> &mem2) const {
  double score = 0.0;
  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &objective = it->first;
    const double weight = it->second->weight;
    if (LessObjective(mem1, mem2, objective))
      score += weight;
  }
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
      case -1: score -= weight;
      case 1: score += weight;
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

double WeightedObjectives::GetNormalizedValue(const vector<uint8> &mem) 
  const {
  double sum = 0.0;

  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    const Info &info = *it->second;
    
    vector<uint8> cur;
    cur.reserve(obj.size());
    for (int i = 0; i < obj.size(); i++) {
      cur.push_back(mem[obj[i]]);
    }

    sum += GetValueFrac(info.observations, cur);
  }

  sum /= (double)weighted.size();
  return sum;
}

void WeightedObjectives::WeightByExamples(const vector< vector<uint8> >
					  &memories) {
  for (Weighted::iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    double score = 0.0;

    const vector<int> &obj = it->first;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);

    int lastvaluefrac = 0.0;
    for (int i = 0; i < memories.size(); i++) {
      vector<uint8> now = GetValues(memories[i], obj);
      double valuefrac = GetValueFrac(values, now);
      score += (valuefrac - lastvaluefrac);
      lastvaluefrac = valuefrac;
    }

    if (score <= 0.0) {
      printf("Bad objective lost more than gained: %f / %s\n",
	     score, ObjectiveToString(obj).c_str());
      it->second->weight = 0.0;
    } else {
      it->second->weight = score;
    }
  }
}

void WeightedObjectives::SaveSVG(const vector< vector<uint8> > &memories,
				 const string &filename) const {
  static const int WIDTH = 2048;
  static const int HEIGHT = 1204;

  string out = TextSVG::Header(WIDTH, HEIGHT);

  ArcFour rc("Zmake colors");

  uint64 skipped = 0;
  int howmany = 500;
  for (Weighted::const_iterator it = weighted.begin();
       howmany-- && it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);
    // printf("%lld distinct values for %s\n", values.size(),
    // ObjectiveToString(obj).c_str());

    const string color = RandomColor(&rc);
    const string startpolyline =
      StringPrintf("  <polyline fill=\"none\" opacity=\"0.5\" stroke=\"%s\""
		   " stroke-width=\"1\" points=\"", color.c_str());
    const string endpolyline = "\" />\n";
    out += "<g>\n";
    out += startpolyline;

    static const int MAXLEN = 256;
    int numleft = MAXLEN;
    // Fill in points as space separated x,y coords
    int lastvalueindex = -1;
    for (int i = 0; i < memories.size(); i++) {
      vector<uint8> now = GetValues(memories[i], obj);
      int valueindex = GetValueIndex(values, now);

      // Allow drawing horizontal lines without interstitial points.
      if (valueindex == lastvalueindex) {
	while (i < memories.size() - 1) {
	  vector<uint8> next = GetValues(memories[i + 1], obj);
	  int nextvalueindex = GetValueIndex(values, next);
	  if (nextvalueindex != valueindex)
	    break;
	  i++;
	  skipped++;
	}
      }
      lastvalueindex = valueindex;

	// Fraction in [0, 1]
      double yf = (double)valueindex / (double)values.size();
      double xf = (double)i / (double)memories.size();
      out += Coords(WIDTH * xf, HEIGHT * (1.0 - yf)) + " ";
      if (numleft-- == 0) {
	out += endpolyline;
	out += startpolyline;
	out += Coords(WIDTH * xf, HEIGHT * (1.0 - yf)) + " ";
	numleft = MAXLEN;
      }

    }

    out += endpolyline;
    out += "</g>\n";
  }

  out += SVGTickmarks(WIDTH, memories.size(), 50.0, 20.0, 12.0);

  out += TextSVG::Footer();
  Util::WriteFile(filename, out);

  printf("Wrote %lld objectives, skipping %lld points, to %s\n", 
	 weighted.size(), skipped, filename.c_str());
}
