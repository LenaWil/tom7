/* TASBOT utilities not general-purpose enough to go into cc-lib. */

#ifndef __TASBOT_UTIL_H
#define __TASBOT_UTIL_H

#include <vector>
#include <string>

#include "tasbot.h"
#include "../cc-lib/arcfour.h"

using namespace std;

template<class T>
static void Shuffle(vector<T> *v) {
  static ArcFour rc("shuffler");
  for (int i = 0; i < v->size(); i++) {
    uint32 h = 0;
    h = (h << 8) | rc.Byte();
    h = (h << 8) | rc.Byte();
    h = (h << 8) | rc.Byte();
    h = (h << 8) | rc.Byte();

    int j = h % v->size();
    if (i != j) {
      swap((*v)[i], (*v)[j]);
    }
  }
}

inline uint32 RandomInt32(ArcFour *rc) {
  uint32 b = rc->Byte();
  b = (b << 8) | rc->Byte();
  b = (b << 8) | rc->Byte();
  b = (b << 8) | rc->Byte();
  return b;
}

inline string RandomColor(ArcFour *rc) {
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

// Random double in [0,1]. Note precision issues.
inline double RandomDouble(ArcFour *rc) {
  return (double)RandomInt32(rc) / (double)(uint32)0xFFFFFFFF;
}

template<class T>
T VectorMax(T def, const vector<T> &v) {
  for (int i = 0; i < v.size(); i++) {
    if (v[i] > def) def = v[i];
  }
  return def;
}

// Truncate unnecessary trailing zeroes to save space.
inline string Coord(double f) {
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

inline string Coords(double x, double y) {
  return Coord(x) + "," + Coord(y);
}

// Width of graphic in pixels, max value of x axis, width of span
// between tickmarks in terms of the units of the x axis,
// the tick height in pixels, the tick font height.
string SVGTickmarks(double width, double maxx, double span,
                    double tickheight, double tickfont);

// Draw a column of dots (as an SVG string), given a vector of values.
// xf is the fraction of the screen width that this column should be
// centered on. maxval is the value considered to be the top of the
// drawing; values above this or below zero are drawn outside the box.
// If chosen_idx is in [0, values.size()) then draw that one bigger.
// Color is an svg color string like "#f00".
string DrawDots(int width, int height,
                const string &color, double xf,
                const vector<double> &values, double maxval,
                int chosen_idx);

#endif
