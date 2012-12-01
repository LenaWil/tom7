
#include "weighted-objectives.h"

#include <algorithm>
#include <set>
#include <string>

#include "tasbot.h"

using namespace std;

WeightedObjectives::WeightedObjectives(const vector< vector<int> > &objs) {
  for (int i = 0; i < objs.size(); i++) {
    weighted[objs[i]] += 1.0;
  }
}

WeightedObjectives *
WeightedObjectives::LoadFromFile(const string &filename) {
  abort();
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
  
void WeightedObjectives::SaveToFile(const string &filename) const {
  string out;
  for (Weighted::const_iterator it = weighted.begin(); 
       it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    char w[128] = {0};
    sprintf(w, "%f", it->second);
    string s = w;
    s += ObjectiveToString(obj);
    out += s + "\n";
  }
  printf("%s\n", out.c_str());
  Util::WriteFile(filename, out);
}

size_t WeightedObjectives::Size() const {
  return weighted.size();
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
#if 0
  for (set< vector<uint8> >::const_iterator it = values.begin();
       it != values.end(); ++it) {
    uvalues.push_back(*it);
  }
#endif
  uvalues.insert(uvalues.begin(), values.begin(), values.end());
  return uvalues;
}

// Find the index of the vector now within the values
// array, which is sorted and unique.
int GetValueIndex(const vector< vector<uint8> > &values,
		  const vector<uint8> &now) {
  return lower_bound(values.begin(), values.end(), now) - values.begin();
}

void WeightedObjectives::SaveSVG(const vector< vector<uint8> > &memories,
				 const string &filename) const {
  string out =
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
    "<!-- Generator: weighted-objectives.cc -->\n"
    "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" "
    "\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\" [\n"
    "<!ENTITY ns_flows \"http://ns.adobe.com/Flows/1.0/\">\n"
    "]>\n"
    "<svg version=\"1.1\"\n"
    " xmlns=\"http://www.w3.org/2000/svg\""
    " xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    " xmlns:a=\"http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/\""
    " x=\"0px\" y=\"0px\" width=\"1024px\" height=\"1024px\""
    " xml:space=\"preserve\">\n";

  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);
    printf("%d distinct values for %s\n", values.size(),
	   ObjectiveToString(obj).c_str());

    out += "<polyline fill=\"none\" opacity=\"0.5\" stroke=\"#123456\""
      " stroke-width=\"1\" points=\"";

    // Fill in points as space separated x,y coords
    for (int i = 0; i < memories.size(); i++) {
      vector<uint8> now = GetValues(memories[i], obj);
      int valueindex = GetValueIndex(values, now);
      // Fraction in [0, 1]
      double yf = (double)valueindex / (double)values.size();
      double xf = (double)i / (double)memories.size();
      out += StringPrintf("%.2f,%.2f ", 1024.0 * xf, 1024.0 * yf);
    }
    out += "\" />\n";
  }

  out += "\n</svg>\n";
  Util::WriteFile(filename, out);
}

