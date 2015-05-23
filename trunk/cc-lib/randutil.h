#ifndef __RANDUTIL_H
#define __RANDUTIL_H

#include "arcfour.h"
#include <cmath>

// Caller owns new-ly allocated pointer.
ArcFour *Substream(ArcFour *rc, int n) {
  vector<uint8> buf;
  buf.resize(64);
  for (int i = 0; i < 4; i++) {
    buf[i] = n & 255;
    n >>= 8;
  }

  for (int i = 4; i < 64; i++) {
    buf[i] = rc->Byte();
  }

  ArcFour *nrc = new ArcFour(buf);
  nrc->Discard(256);
  return nrc;
}

template<class T>
static void Shuffle(ArcFour *rc, vector<T> *v) {
  for (int i = 0; i < v->size(); i++) {
    uint32 h = 0;
    h = (h << 8) | rc->Byte();
    h = (h << 8) | rc->Byte();
    h = (h << 8) | rc->Byte();
    h = (h << 8) | rc->Byte();

    // XXX BIAS!
    int j = h % v->size();
    if (i != j) {
      swap((*v)[i], (*v)[j]);
    }
  }
}

// In [0, 1].
float RandFloat(ArcFour *rc) {
  uint32 uu = 0u;
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  return (float)((uu   & 0x7FFFFFFF) / 
		 (double)0x7FFFFFFF);
};

double RandDouble(ArcFour *rc) {
  uint64 uu = 0u;
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  return ((uu &   0x3FFFFFFFFFFFFFFFULL) / 
	  (double)0x3FFFFFFFFFFFFFFFULL);
};

uint64 Rand64(ArcFour *rc) {
  uint64 uu = 0ULL;
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  return uu;
};

uint32 Rand32(ArcFour *rc) {
  uint32 uu = 0ULL;
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  return uu;
};

// Generates two at once, so needs some state.
struct RandomGaussian {
  bool have = false;
  double next = 0;
  ArcFour *rc = nullptr;
  explicit RandomGaussian(ArcFour *rc) : rc(rc) {}
  double Next() {
    if (have) {
      have = false;
      return next;
    } else {
      double v1, v2, sqnorm;
      // Generate a non-degenerate random point in the unit circle by
      // rejection sampling.
      do {
	v1 = 2.0 * RandDouble(rc) - 1.0;
	v2 = 2.0 * RandDouble(rc) - 1.0;
	sqnorm = v1 * v1 + v2 * v2;
      } while (sqnorm >= 1.0 || sqnorm == 0.0);
      double multiplier = sqrt(-2.0 * log(sqnorm) / sqnorm);
      next = v2 * multiplier;
      have = true;
      return v1 * multiplier;
    }
  }
};

// If you need many, RandomGaussian will be twice as fast.
double OneRandomGaussian(ArcFour *rc) {
  return RandomGaussian{rc}.Next();
}

#endif
