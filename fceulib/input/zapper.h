#ifndef _ZAPPER_H_
#define _ZAPPER_H_

#include "../types.h"
#include "../input.h"

struct ZAPPER {
  uint32 mzx,mzy,mzb;
  int zap_readbit;
  uint8 bogo;
  int zappo;
  uint64 zaphit;
  uint32 lastInput;
};

extern INPUTC *FCEU_InitZapper(int w);


#endif
