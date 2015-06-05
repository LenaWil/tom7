
#ifndef __POINT_H
#define __POINT_H

#include <cmath>
#include "base/stringprintf.h"

struct Pt {
  double x = 0.0;
  double y = 0.0;
  Pt(double x, double y) : x(x), y(y) {}
  Pt() {}
};

inline double SqDistance(Pt a, Pt b) {
  double dx = a.x - b.x, dy = a.y - b.y;
  return dx * dx + dy * dy;
}

inline double Distance(Pt a, Pt b) {
  double dx = a.x - b.x, dy = a.y - b.y;
  return sqrt(dx * dx + dy * dy);
}

inline std::string Ptos(Pt p) {
  return StringPrintf("%.1f,%.1f", p.x, p.y);
};


#endif
