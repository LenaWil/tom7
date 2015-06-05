
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
  bool Invert2(Pt current, Pt output, Pt *input,
	       vector<Pt> *path);

private:
  static constexpr double PI = 3.14159265358979323846264338327950288419716939937510;
  static constexpr double TWOPI = (2.0 * PI); // 6.28318530718

  ArcFour rc;
  const F &f;
  const int xsteps, ysteps, xres, yres;
  vector<vector<vector<Pt>>> backward;
};

template<class F>
struct InvertRect {
  // Since invert2 works best right now, we ignore the
  InvertRect(const F &f,
	     double xin_min, double xin_max,
	     double yin_min, double yin_max,
	     double xout_min, double xout_max,
	     double yout_min, double yout_max);

  bool Invert(Pt current, Pt Output, Pt *input);

private:
  Pt NormOut(Pt out);
  Pt NormIn(Pt in);
  Pt UnNormIn(Pt in);
  Inversion<F> inversion;
  static constexpr int BOGUS_STEPS = 10;
  static constexpr int BOGUS_RESOLUTION = 2;

  const double xin_min, xin_len, yin_min, yin_len;
  const double xin_len_inv, yin_len_inv;
  const double xout_min, xout_len_inv, yout_min, yout_len_inv;
};



// Template implementations follow.

template<class F>
bool Inversion<F>::Invert2(Pt current, Pt output, Pt *input,
			   vector<Pt> *path) {
  static constexpr double ERROR_TARGET = 0.0005;
  static constexpr double SQ_ERROR_TARGET = ERROR_TARGET * ERROR_TARGET;

  // TODO: This constant should be tuned at initialization time, or the
  // algorithm should be able to start with a high value but be robust
  // against jumping to a slighly better match that's super far away;
  // we're trying to minimize both the error and the jump from the
  // current location.

  double current_stride = 0.001;
  double current_error;

  auto ErrorFn = [this, output, current](Pt cand) -> double {
    // Take into account both the error how far we've gone?
    return SqDistance(output, f(cand)); /* + SqDistance(cand, current) / 100.0; */
  };

  int count = 0;
  while ( (current_error = ErrorFn(current)) > SQ_ERROR_TARGET) {
    // Inspect a small area around the current guess.

    static constexpr int NUM_PTS = 9;
    static_assert(NUM_PTS >= 3, "With fewer than 3 points, we may never "
		  "even have an angle that makes progress (actually maybe "
		  "3 is not even enough...)");
    
    double angle = RandDouble(&rc) * TWOPI;
    static constexpr double STEP_RADIANS = TWOPI / NUM_PTS;

    bool found_next = false;
    Pt next;
    for (int i = 0; i < NUM_PTS; i++) {
      Pt candidate(current.x + sin(angle) * current_stride,
		   current.y + cos(angle) * current_stride);
      double cand_err = ErrorFn(candidate);
      if (cand_err < current_error) {
	found_next = true;
	next = candidate;
      }
      angle += STEP_RADIANS;
    }

    if (found_next) {
      current = next;
      if (path != nullptr) {
	path->push_back(current);
      }
    } else {
      // Assume that all points jump over the local minimum, and
      // narrow.
      if (!found_next) current_stride *= 0.7;

      count++;
      if (count > 1000)
	return false;
    }

    // PERF we could save f(next) and error which we already computed.
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
      if (xb >= 0 && xb < xres &&
	  yb >= 0 && yb << yres) {
	backward[yb][xb].emplace_back(xx, yy);
      } else {
	// fprintf(stderr, "F returned value out of range!\n");
	// abort();
      }
    }
  }
  
}

template<class F>
InvertRect<F>::InvertRect(const F &f,
			  double xin_min, double xin_max,
			  double yin_min, double yin_max,
			  double xout_min, double xout_max,
			  double yout_min, double yout_max)
  : inversion(f, BOGUS_STEPS, BOGUS_STEPS,
	      BOGUS_RESOLUTION, BOGUS_RESOLUTION),
    xin_min(xin_min), xin_len(xin_max - xin_min),
    yin_min(yin_min), yin_len(yin_max - yin_min),
    xin_len_inv(1.0 / xin_len),
    yin_len_inv(1.0 / yin_len),
    xout_min(xout_min), xout_len_inv(1.0 / (xout_max - xout_min)),
    yout_min(yout_min), yout_len_inv(1.0 / (yout_max - yout_min)) {}

template<class F>
bool InvertRect<F>::Invert(Pt current, Pt output, Pt *input) {
  Pt ninput;
  if (inversion.Invert2(NormIn(current), NormOut(output),
			&ninput, nullptr)) {
    *input = UnNormIn(ninput);
    return true;
  }
  return false;
}

template<class F>
Pt InvertRect<F>::NormOut(Pt out) {
  return Pt((out.x - xout_min) * xout_len_inv,
	    (out.y - yout_min) * yout_len_inv);
}

template<class F>
Pt InvertRect<F>::NormIn(Pt in) {
  return Pt((in.x - xin_min) * xin_len_inv,
	    (in.y - yin_min) * yin_len_inv);
}

template<class F>
Pt InvertRect<F>::UnNormIn(Pt in) {
  return Pt(in.x * xin_len + xin_min,
	    in.y * yin_len + yin_min);
}

#endif
