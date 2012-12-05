
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
    weighted[objs[i]] = 1.0;
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
    const double weight = it->second;
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
    const double weight = it->second;
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
static int GetValueIndex(const vector< vector<uint8> > &values,
			 const vector<uint8> &now) {
  return lower_bound(values.begin(), values.end(), now) - values.begin();
}

void WeightedObjectives::WeightByExamples(const vector< vector<uint8> > &memories) {
  for (Weighted::iterator it = weighted.begin();
       it != weighted.end(); ++it) {
    double score = 0.0;

    const vector<int> &obj = it->first;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);

    int lastvaluefrac = 0.0;
    for (int i = 0; i < memories.size(); i++) {
      vector<uint8> now = GetValues(memories[i], obj);
      int valueindex = GetValueIndex(values, now);
      double valuefrac = (double)valueindex / values.size();
      score += (valuefrac - lastvaluefrac);
      lastvaluefrac = valuefrac;
    }

    if (score <= 0.0) {
      printf("Bad objective lost more than gained: %f / %s\n",
	     score, ObjectiveToString(obj).c_str());
      it->second = 0.0;
    } else {
      it->second = score;
    }
  }
}

// Truncate unnecessary trailing zeroes to save space.
static string Coord(double f) {
  char s[24];
  int n = sprintf(s, "%.3f", f) - 1;
  while (n >= 0 && s[n] == '0') {
    s[n] = '\0';
    n--;
  }
  if (n <= 0) return "0";
  else if (s[n] == '.') s[n] = '\0';

  return (string)s;
}

static string Coords(double x, double y) {
  return Coord(x) + "," + Coord(y);
}

static string RandomColor(ArcFour *rc) {
  // For a white background there must be at least one color channel that
  // is half off. Mask off one of the three top bits at random:
  uint8 rr = 0x7F, gg = 0xFF, bb = 0xFF;
  for (int i = 0; i < 30; i++) {
    if (rc->Byte() & 1) {
      uint8 tt = rr;
      rr = gg;
      gg = bb;
      bb = tt;
    }
  }

  return StringPrintf("#%02x%02x%02x",
		      rr & rc->Byte(), gg & rc->Byte(), bb & rc->Byte());
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

  uint64 skipped = 0;
  int howmany = 500;
  for (Weighted::const_iterator it = weighted.begin();
       howmany-- && it != weighted.end(); ++it) {
    const vector<int> &obj = it->first;
    // All the distinct values this objective takes on, in order.
    vector< vector<uint8> > values = GetUniqueValues(memories, obj);
    printf("%lld distinct values for %s\n", values.size(),
	   ObjectiveToString(obj).c_str());

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

  printf("Wrote %lld objectives, skipping %lld points!\n", 
	 weighted.size(), skipped);

  // Show ticks.
  const int SPAN = 50;
  const double TICKHEIGHT = 20.0;
  const double TICKFONT = 12.0;
  bool longone = true;
  for (int x = 0; x < memories.size(); x += SPAN) {
    double xf = x / (double)memories.size();
    out += StringPrintf("  <polyline fill=\"none\" opacity=\"0.5\" stroke=\"#000000\""
			" stroke-width=\"1\" points=\"%f,0 %f,%f\" />\n",
			WIDTH * xf, WIDTH * xf, 
			longone ? TICKHEIGHT * 2 : TICKHEIGHT);
    if (longone)
      out += StringPrintf("<text x=\"%f\" y=\"%f\" font-size=\"%f\">"
			  "<tspan fill=\"#000000\">%d</tspan>"
			  "</text>\n",
			  WIDTH * xf + 3.0, 2.0 * TICKHEIGHT + 2.0, TICKFONT, x);

    longone = !longone;
  }

  printf("%s %s %s %s\n", Coord(2.0).c_str(),
	 Coord(1.234567).c_str(), 
	 Coord(0.0).c_str(),
	 Coord(1.200).c_str());

  out += "\n</svg>\n";
  Util::WriteFile(filename, out);
}
