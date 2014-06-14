
#ifndef __CONTROLLERS_H
#define __CONTROLLERS_H

#include "10goto20.h"

// These are double-valued properties of a moment in a note.
// Most controllers have nominal ranges but extend to the
// natural "out of bounds" semantics.
enum Controller {
  /* Must be present.
     In Hz. Must be positive and normally should be in (0,
     SAMPLING_RATE / 2], but nobody other than Nyquist is stopping you
     from going higher... */
  FREQUENCY = 0,
  /* Must be present.
     nominally in [0, 1] but okay for this to be out of that range (HDR). */
  AMPLITUDE = 1,
  /* argument in [-1, 1] (full left to full right), but okay for this to be out
     of range (HDR). */
  PAN = 2,
};

/* Not a controller; must not appear in Controllers sets. */
#define INVALID_CONTROLLER 255

// These objects have (mutable) value semantics and efficient move
// constructors. Just pass 'em around.
struct Controllers {
  // PERF initialize to hold 2, since frequency and amplitude are
  // required anyway.
  ~Controllers();
  Controllers() : size(0), capacity(0), types(NULL), values(NULL) {}
  Controllers(const Controllers &);
  Controllers(Controllers &&);
  Controllers &operator =(const Controllers &);
  Controllers &operator =(Controllers &&rhs);

  char size, capacity;
  char *types;
  double *values;

  void Set(Controller c, double v);
  bool Get(Controller c, double *v) const;
  double GetRequired(Controller c) const;
  double GetOrDefault(Controller c, double d) const {
    double v;
    if (!Get(c, &v)) return d;
    else return v;
  }

 private:
  void Reserve(int s);
};

#endif
