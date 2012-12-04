
#include "weighted-objectives.h"

#include <algorithm>
#include <set>
#include <string>
#include <iostream>
#include <sstream>

#include "tasbot.h"
#include "../cc-lib/arcfour.h"

using namespace std;

WeightedObjectives::WeightedObjectives() {}

WeightedObjectives::WeightedObjectives(const vector< vector<int> > &objs) {
  for (int i = 0; i < objs.size(); i++) {
    weighted[objs[i]] += 1.0;
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
    wo->weighted.insert(make_pair(locs, d));  
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
  printf("%s\n", out.c_str());
  Util::WriteFile(filename, out);
}

size_t WeightedObjectives::Size() const {
  return weighted.size();
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


double WeightedObjectives::GetNumLess(const vector<uint8> &mem1,
				      const vector<uint8> &mem2) const {
  double score = 0.0;
  for (Weighted::const_iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    const vector<int> &objective = it->first;
    const double weight = it->second;
    if (LessObjective(mem1, mem2, objective))
      score += weight;
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
  static const int WIDTH = 2048;
  static const int HEIGHT = 1204;

  string out =
    StringPrintf(
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
    " x=\"0px\" y=\"0px\" width=\"%dpx\" height=\"%dpx\""
    " xml:space=\"preserve\">\n", WIDTH, HEIGHT);

  ArcFour rc("Zmake colors");

  int howmany = 50;
  for (Weighted::const_iterator it = weighted.begin();
       howmany-- && it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);
    printf("%d distinct values for %s\n", values.size(),
	   ObjectiveToString(obj).c_str());

    string color = StringPrintf("#%02x%02x%02x",
				rc.Byte(), rc.Byte(), rc.Byte());
    const string startpolyline =
      StringPrintf("  <polyline fill=\"none\" opacity=\"0.5\" stroke=\"%s\""
		   " stroke-width=\"1\" points=\"", color.c_str());
    const string endpolyline = "\" />\n";
    out += "<g>\n";
    out += startpolyline;

    static const int MAXLEN = 256;
    int numleft = MAXLEN;
    // Fill in points as space separated x,y coords
    for (int i = 0; i < memories.size(); i++) {
      vector<uint8> now = GetValues(memories[i], obj);
      int valueindex = GetValueIndex(values, now);
      // Fraction in [0, 1]
      double yf = (double)valueindex / (double)values.size();
      double xf = (double)i / (double)memories.size();
      out += StringPrintf("%.3f,%.3f ", WIDTH * xf, HEIGHT * (1.0 - yf));
      if (numleft-- == 0) {
	out += endpolyline;
	out += startpolyline;
	numleft = MAXLEN;
      }
    }

    out += endpolyline;
    out += "</g>\n";
  }

  // Show ticks.
  const int SPAN = 128;
  const double TICKHEIGHT = 20.0;
  const double TICKFONT = 12.0;
  for (int x = 0; x < WIDTH; x += SPAN) {
    double xf = x / (double)memories.size();
    out += StringPrintf("  <polyline fill=\"none\" opacity=\"0.5\" stroke=\"#000000\""
			" stroke-width=\"1\" points=\"%f,0 %f,%f\" />\n",
			WIDTH * xf, WIDTH * xf, TICKHEIGHT);
    // TEXT
    out += StringPrintf("<text x=\"%f\" y=\"%f\" font-size=\"%f\">" ^
			"<tspan fill=\"#000000\">%d</tspan>"
			"</text>\n",
			WIDTH * xf, TICKHEIGHT + 2.0, TICKFONT, x);
  }

  out += "\n</svg>\n";
  Util::WriteFile(filename, out);
}
