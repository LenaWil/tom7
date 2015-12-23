#ifndef __RANDUTIL_H
#define __RANDUTIL_H

#include "arcfour.h"
#include <cmath>
#include <cstdint>
#include <vector>

using uint8 = uint8_t;
using uint64 = uint64_t;
using uint32 = uint32_t;

// Caller owns new-ly allocated pointer.
inline ArcFour *Substream(ArcFour *rc, int n) {
  std::vector<uint8> buf;
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

// In [0, 1].
inline float RandFloat(ArcFour *rc) {
  uint32 uu = 0u;
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  return (float)((uu   & 0x7FFFFFFF) / 
		 (double)0x7FFFFFFF);
};

inline double RandDouble(ArcFour *rc) {
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

inline uint64 Rand64(ArcFour *rc) {
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

inline uint32 Rand32(ArcFour *rc) {
  uint32 uu = 0ULL;
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  uu = rc->Byte() | (uu << 8);
  return uu;
};

// Generate uniformly distributed numbers in [0, n - 1].
// n must be greater than or equal to 2.
inline uint32 RandTo(ArcFour *rc, uint32 n) {
  // We use rejection sampling, as is standard, but with
  // a modulus that's the next largest power of two. This
  // means that we succeed half the time (worst case).
  //
  // First, compute the mask. Note that 2^k will be 100...00
  // and so 2^k-1 is 011...11. This is the mask we're looking
  // for. The input may not be a power of two, however. Make
  // sure any 1 bit is propagated to every position less
  // significant than it. (For 64-bit constants, we'd need
  // another shift for 32.)
  // 
  // This ought to reduce to a constant if the argument is
  // a compile-time constant.
  uint32 mask = n - 1;
  mask |= mask >> 1;
  mask |= mask >> 2;
  mask |= mask >> 4;
  mask |= mask >> 8;
  mask |= mask >> 16;

  // Now, repeatedly generate random numbers, modulo that
  // power of two.

  // PERF: If the number is small, we only need Rand16, etc.
  for (;;) {
    const uint32 x = Rand32(rc) & mask;
    if (x < n) return x;
  }
}

template<class T>
static void Shuffle(ArcFour *rc, std::vector<T> *v) {
  for (int i = 0; i < v->size(); i++) {
    uint32 h = 0;
    h = (h << 8) | rc->Byte();
    h = (h << 8) | rc->Byte();
    h = (h << 8) | rc->Byte();
    h = (h << 8) | rc->Byte();

    // XXX only works for 4 billion elements or fewer!
    int j = RandTo(rc, v->size());
    if (i != j) {
      swap((*v)[i], (*v)[j]);
    }
  }
}

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
inline double OneRandomGaussian(ArcFour *rc) {
  return RandomGaussian{rc}.Next();
}

#endif
