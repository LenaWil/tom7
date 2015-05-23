
#ifndef __POINT_H
#define __POINT_H

#include <cmath>

struct Pt {
  double x = 0.0;
  double y = 0.0;
  Pt(double x, double y) : x(x), y(y) {}
  Pt() {}
};

inline double SqDistance(Pt a, Pt b) {
  return (a.x - b.x) * (a.y - b.y);
}

inline double Distance(Pt a, Pt b) {
  return sqrt((a.x - b.x) * (a.y - b.y));
}

#endif
