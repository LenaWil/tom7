#ifndef __FILTER_H
#define __FILTER_H

#include "fcoeff-constants.h"

struct Filter {
  int32 NeoFilterSound(int32 *in, int32 *out, uint32 inlen, int32 *leftover);
  void MakeFilters(int32 rate);
  void SexyFilter(int32 *in, int32 *out, int32 count);

 private:
  // These are initialized by makefilters in sound.cc.
  int32 sq2coeffs[SQ2NCOEFFS];
  int32 coeffs[NCOEFFS];

  uint32 mrindex;
  uint32 mrratio;

  int64 sexyfilter2_acc = 0;
  int64 sexyfilter_acc1 = 0, sexyfilter_acc2 = 0;

  void SexyFilter2(int32 *in, int32 count);
};

#endif
