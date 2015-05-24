
#ifndef __INVERSION_H
#define __INVERSION_H

#include <vector>
#include <cmath>

#include "point.h"
#include "arcfour.h"
#include "randutil.h"

using namespace std;

// Approximately invert an arbitrary 2D function for planning paths.
// Obviously this can often be done analytically, but:
//    - This approach allows for finding a solution that's close
//      to a current value, which is useful when the function is
//      not injective.
//    - It allows for easily toying with mechanisms without having
//      to do any new math.

template<class F>
struct Inversion {
  // F is a function Pt -> Pt. Its domain and range should be 
  // ([0, 1] x [0, 1]). We assume F is fast to compute.
  //
  // xsteps and ysteps give the resolution of the input drivers.
  // xres and yres give the resolution of the output map.
  Inversion(const F &f, int xsteps, int ysteps,
	    int xres, int yres);
  
  // Given an output, return an input that produces approximately
  // that output. In cases where there are multiple inputs, choose
  // the one closest (Euclidean distance) to 'current'. Returns
  // false if there are none "close" enough.
  bool Invert(Pt current, Pt output, Pt *input) const;

  // Same, not using table, just search from current point.
  bool Invert2(Pt current, Pt output, Pt *input);

private:
  ArcFour rc;
  const F &f;
  const int xsteps, ysteps, xres, yres;
  vector<vector<vector<Pt>>> backward;
};


// Template implementations follow.

template<class F>
bool Inversion<F>::Invert2(Pt current, Pt output, Pt *input) {
  static constexpr double ERROR_TARGET = 0.01;
  static constexpr double SQ_ERROR_TARGET = ERROR_TARGET * ERROR_TARGET;

  double last_stride = 1.0;
  double current_error;

  int count = 0;
  while ( (current_error = SqDistance(output, f(current))) > SQ_ERROR_TARGET) {
    // Get a new guess. Ideally we'd have the derivative at
    // this point, which maybe is what we should really be
    // inserting in a table.
    
    // Pick a random point within the circle of radius last_stride;
    // rejection sampling is likely to be fastest here.
    double v1, v2, sqnorm;
    do {
      v1 = 2.0 * RandDouble(&rc) - 1.0;
      v2 = 2.0 * RandDouble(&rc) - 1.0;
      sqnorm = v1 * v1 + v2 * v2;
    } while (sqnorm >= 1.0 || sqnorm == 0.0);
    v1 *= last_stride;
    v2 *= last_stride;

    Pt candidate{output.x + v1, output.y + v2};
    Pt cand_res = f(candidate);
    if (SqDistance(output, f(candidate)) < current_error) {
      //      printf("Accepted %f %f sqerror %f.\n", cand_res.x, cand_res.y,
      //	     SqDistance(output, f(candidate)));
      current = candidate;
      // PERF we immediately recompute f(candidate) and distance..
    }
    last_stride = sqrt(sqnorm);

    count++;
    if (count > 1000)
      return false;
  }

  *input = current;
  return true;
}

template<class F>
bool Inversion<F>::Invert(Pt current, Pt output, Pt *input) const {
  // Find the closest bucket.
  int xb = round(output.x * (xres - 1));
  int yb = round(output.y * (yres - 1));

  if (xb < 0 || xb >= xres || yb < 0 || yb >= yres) {
    // printf("  %d %d outside bucket map.\n", xb, yb);
    return false;
  }

  // XXX There can just be "holes" -- we should fill these in
  // during initialization?
  const vector<Pt> &bucket = backward[yb][xb];
  if (bucket.empty()) {
    // printf("  bucket at %d %d empty :(\n", xb, yb);
    return false;
  }

  // Find the closest one.
  Pt closest = bucket[0];
  double sqdist = SqDistance(current, closest);
  for (int i = 1; i < bucket.size(); i++) {
    double sd = SqDistance(current, bucket[i]);
    if (sd < sqdist) {
      closest = bucket[i];
      sqdist = sd;
    }
  }

  // XXX We have an approximate solution, but we should do some
  // gradient descent to find a more exact solution!

  *input = closest;
  return true;
}

template<class F>
Inversion<F>::Inversion(const F &f, int xsteps, int ysteps,
			int xres, int yres) :
  rc("inv"),
  f(f),
  xsteps(xsteps), ysteps(ysteps),
  xres(xres), yres(yres),
  backward(yres, vector<vector<Pt>>(yres, vector<Pt>{})) {
  // Populate backward map. v[y][x] are values in the input
  // that mapped near here. Can be empty!

  for (int y = 0; y < ysteps; y++) {
    double yy = y / double(ysteps);
    for (int x = 0; x < xsteps; x++) {
      double xx = x / double(xsteps);
      Pt res = f(Pt{xx, yy});
      int xb = round(res.x * (xres - 1));
      int yb = round(res.y * (yres - 1));
      if (xb < 0 || xb >= xres || 
	  yb < 0 || yb >= yres) {
	fprintf(stderr, "F returned value out of range!\n");
	abort();
      }
      backward[yb][xb].emplace_back(xx, yy);
    }
  }
  
}

#endif
