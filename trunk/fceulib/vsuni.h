#ifndef __VSUNI_H
#define __VSUNI_H

#include "state.h"
#include "types.h"
#include "fceu.h"
#include "fc.h"

// This is the VS. UniSystem, I believe, an arcade machine that runs
// modified NES games.
//
// https://en.wikipedia.org/wiki/Nintendo_VS._System
//
// I don't really test this one, so it may not work.

struct VSUni {
  explicit VSUni(FC *fc);

  void FCEU_VSUniPower();
  void FCEU_VSUniCheck(uint64 md5partial, int *, uint8 *);
  void FCEU_VSUniDraw(uint8 *XBuf);

  void FCEU_VSUniToggleDIP(int);  /* For movies and netplay */
  void FCEU_VSUniCoin();
  void FCEU_VSUniSwap(uint8 *j0, uint8 *j1);

  DECLFR_RET A2002_Gumshoe_Direct(DECLFR_ARGS);
  DECLFR_RET VSSecRead_Direct(DECLFR_ARGS);
  DECLFR_RET A2002_Topgun_Direct(DECLFR_ARGS);
  DECLFR_RET A2002_MBJ_Direct(DECLFR_ARGS);
  DECLFR_RET XevRead_Direct(DECLFR_ARGS);
  void B2000_2001_2C05_Direct(DECLFW_ARGS);

  SFORMAT *FCEUVSUNI_STATEINFO() {
    return stateinfo.data();
  }

  struct VSUniEntry;
  
  // Accessed directly in input.cc.
  uint8 coinon = 0;
  uint8 vsdip = 0;
 private:
  const VSUniEntry *curvs = nullptr;

  const uint8 *secptr = nullptr;
  uint8 VSindex = 0;

  int curppu = 0;
  int64 curmd5 = 0;

  readfunc OldReadPPU = nullptr;
  writefunc OldWritePPU[2] = {nullptr, nullptr};
  
  uint8 xevselect = 0;
  
  std::vector<SFORMAT> stateinfo;
  FC *fc = nullptr;
};

#endif
