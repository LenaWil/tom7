#ifndef __CART_H
#define __CART_H

#include "types.h"
#include "fceu.h"

#include "fc.h"

struct CartInterface {
  explicit CartInterface(FC *fc) : fc(fc) {}
  virtual ~CartInterface() {}
  /* Set by mapper/board code: */
  virtual void Power() {}
  virtual void Reset() {}
  virtual void Close() {}

  // This is a codification of an awful hack whereby the PPU calls
  // MMC5 code (if that is the active mapper) for each scanline.
  // Not my fault! -tom7
  virtual void MMC5HackHB(int scanline) {
    fprintf(stderr, "MMC5Hack should not be called on "
	    "anything but MMC5.\n");
    abort();
  }
  
 protected:
  FC *fc = nullptr;
 private:
  CartInterface() = delete;
};

// Same idea, but for old _init style mappers that
// do their work by modifying global variables.
struct MapInterface {
  explicit MapInterface(FC *fc) : fc(fc) {}
  virtual ~MapInterface() {}
  virtual void StateRestore(int version) {}
  virtual void MapperReset() {}
  virtual void MapperClose() {}
protected:
  FC *fc = nullptr;
 private:
  MapInterface() = delete; 
};

struct CartInfo {
  // Maybe some of this should go into CartInterface.

  /* Pointers to memory to save/load. */
  uint8 *SaveGame[4];
  /* How much memory to save/load. */
  uint32 SaveGameLen[4];

  /* Set by iNES/UNIF loading code. */
  /* As set in the header or chunk.
     iNES/UNIF specific.  Intended
     to help support games like "Karnov"
     that are not really MMC3 but are
     set to mapper 4. */
  int mirror;
  /* Presence of an actual battery. */
  int battery;
  uint8 MD5[16];
  /* Should be set by the iNES/UNIF loading
     code, used by mapper/board code, maybe
     other code in the future. */
  uint32 CRC32;
};

struct Cart {
  void FCEU_SaveGameSave(CartInfo *LocalHWInfo);
  void FCEU_LoadGameSave(CartInfo *LocalHWInfo);
  void FCEU_ClearGameSave(CartInfo *LocalHWInfo);

  uint8 *Page[32] = {};
  uint8 *VPage[8] = {};
  uint8 *MMC5SPRVPage[8] = {};
  uint8 *MMC5BGVPage[8] = {};

  void ResetCartMapping();
  void SetupCartPRGMapping(int chip, uint8 *p, uint32 size, int ram);
  void SetupCartCHRMapping(int chip, uint8 *p, uint32 size, int ram);
  void SetupCartMirroring(int m, int hard, uint8 *extra);
  
  // hack, movie.cpp has to communicate with this function somehow
  // Maybe should always be true? -tom7
  int disableBatteryLoading = 0;
  
  uint8 *PRGptr[32] = {};
  uint8 *CHRptr[32] = {};
  
  uint32 PRGsize[32] = {};
  uint32 CHRsize[32] = {};
  
  uint32 PRGmask2[32] = {};
  uint32 PRGmask4[32] = {};
  uint32 PRGmask8[32] = {};
  uint32 PRGmask16[32] = {};
  uint32 PRGmask32[32] = {};
  
  uint32 CHRmask1[32] = {};
  uint32 CHRmask2[32] = {};
  uint32 CHRmask4[32] = {};
  uint32 CHRmask8[32] = {};

  void setprg2(uint32 A, uint32 V);
  void setprg4(uint32 A, uint32 V);
  void setprg8(uint32 A, uint32 V);
  void setprg16(uint32 A, uint32 V);
  void setprg32(uint32 A, uint32 V);

  void setprg2r(int r, unsigned int A, unsigned int V);
  void setprg4r(int r, unsigned int A, unsigned int V);
  void setprg8r(int r, unsigned int A, unsigned int V);
  void setprg16r(int r, unsigned int A, unsigned int V);
  void setprg32r(int r, unsigned int A, unsigned int V);

  void setchr1r(int r, unsigned int A, unsigned int V);
  void setchr2r(int r, unsigned int A, unsigned int V);
  void setchr4r(int r, unsigned int A, unsigned int V);
  void setchr8r(int r, unsigned int V);

  void setchr1(unsigned int A, unsigned int V);
  void setchr2(unsigned int A, unsigned int V);
  void setchr4(unsigned int A, unsigned int V);
  void setchr8(unsigned int V);

  void setvram4(uint32 A, uint8 *p);
  void setvram8(uint8 *p);

  void setvramb1(uint8 *p, uint32 A, uint32 b);
  void setvramb2(uint8 *p, uint32 A, uint32 b);
  void setvramb4(uint8 *p, uint32 A, uint32 b);
  void setvramb8(uint8 *p, uint32 b);

  void setmirror(int t);
  void setmirrorw(int a, int b, int c, int d);
  void setntamem(uint8 *p, int ram, uint32 b);

  Cart(FC *fc);
  
  // TODO: Kill these.
  static DECLFW_RET CartBW(DECLFW_ARGS);
  static DECLFR_RET CartBR(DECLFR_ARGS);
  static DECLFR_RET CartBROB(DECLFR_ARGS);

  // TODO: Indirect static hooks (which go through the global object)
  // should instead get a local cart object and call these.
  DECLFR_RET CartBR_Direct(DECLFR_ARGS);
  DECLFR_RET CartBROB_Direct(DECLFR_ARGS);
  DECLFW_RET CartBW_Direct(DECLFW_ARGS);

private:
  uint8 PRGIsRAM[32] = { };  /* This page is/is not PRG RAM. */

  // Aliases VPage, don't know why. Fix? -tom7
  uint8 **VPageR = nullptr;
  
  // See comment on ResetCartMapping where negative offsets of nothing
  // are used..? TODO: Sort this out.
  uint8 nothing_safetynet[65536] = { };
  uint8 nothing[8192] = { };

  /* 16 are (sort of) reserved for UNIF/iNES and 16 to map other stuff. */
  int CHRram[32] = { };
  int PRGram[32] = { };

  int mirrorhard = 0;

  void setpageptr(int s, uint32 A, uint8 *p, int ram);

  FC *fc;
};

#define MI_H 0
#define MI_V 1
#define MI_0 2
#define MI_1 3

#endif
