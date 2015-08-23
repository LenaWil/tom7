#ifndef __PPU_H
#define __PPU_H

#include "state.h"
#include <utility>
#include <vector>

#include "fceu.h"
#include "fc.h"

struct PPU {
 public:
  PPU(FC *fc);

  void FCEUPPU_Reset();
  void FCEUPPU_Power();
  int FCEUPPU_Loop(int skip);

  void FCEUPPU_LineUpdate();
  void FCEUPPU_SetVideoSystem(int w);

  void FCEUPPU_SaveState();
  void FCEUPPU_LoadState(int version);

  // 0 to keep 8-sprites limitation, 1 to remove it
  void FCEUI_DisableSpriteLimitation(int a);


  void (*PPU_hook)(FC *, uint32 A) = nullptr;
  void (*GameHBIRQHook)(FC *) = nullptr;
  void (*GameHBIRQHook2)(FC *) = nullptr;


  uint8 NTARAM[0x800] = {}, PALRAM[0x20] = {};
  uint8 SPRAM[0x100] = {}, SPRBUF[0x100] = {};
  // for 0x4/0x8/0xC addresses in palette, the ones in
  // 0x20 are 0 to not break fceu rendering.
  uint8 UPALRAM[0x03] = {};

  uint8 PPU_values[4] = {};

  int MMC5Hack = 0;
  uint8 mmc5ABMode = 0; /* A=0, B=1 */
  uint32 MMC5HackVROMMask = 0;
  uint8 *MMC5HackExNTARAMPtr = nullptr;
  uint8 *MMC5HackVROMPTR = nullptr;
  uint8 MMC5HackCHRMode = 0;
  uint8 MMC5HackSPMode = 0;
  uint8 MMC50x5130 = 0;
  uint8 MMC5HackSPScroll = 0;
  uint8 MMC5HackSPPage = 0;

  /* For cart.c and banksw.h, mostly */
  uint8 *vnapage[4] = { nullptr, nullptr, nullptr, nullptr };
  uint8 PPUNTARAM = 0;
  uint8 PPUCHRRAM = 0;

  // scanline is equal to the current visible scanline we're on.
  int scanline = 0;
  int g_rasterpos = 0;


  // TODO: Kill these.
  // XXX do they need to be exposed, btw? that might have been
  // my mistake.
  static DECLFR_RET A2002(DECLFR_ARGS);
  static DECLFR_RET A2004(DECLFR_ARGS);
  static DECLFR_RET A200x(DECLFR_ARGS);
  static DECLFR_RET A2007(DECLFR_ARGS);
  
  // TODO: Indirect static hooks (which go through the global object)
  // should instead get a local ppu object and call these.
  DECLFR_RET A2002_Direct(DECLFR_ARGS);
  DECLFR_RET A2004_Direct(DECLFR_ARGS);
  DECLFR_RET A200x_Direct(DECLFR_ARGS);
  DECLFR_RET A2007_Direct(DECLFR_ARGS);

  
  // Some static methods herein call these, but they should be
  // getting a local ppu object rather than using the global one.
  void B2000_Direct(DECLFW_ARGS);
  void B2001_Direct(DECLFW_ARGS);
  void B2002_Direct(DECLFW_ARGS);
  void B2003_Direct(DECLFW_ARGS);
  void B2004_Direct(DECLFW_ARGS);
  void B2005_Direct(DECLFW_ARGS);
  void B2006_Direct(DECLFW_ARGS);
  void B2007_Direct(DECLFW_ARGS);
  void B4014_Direct(DECLFW_ARGS);

  const std::vector<SFORMAT> &FCEUPPU_STATEINFO() {
    return stateinfo;
  }

 private:
  const std::vector<SFORMAT> stateinfo;

  void FetchSpriteData();
  void RefreshLine(int lastpixel);
  void RefreshSprites();
  void CopySprites(uint8 *target);

  void Fixit1();
  void Fixit2();
  void ResetRL(uint8 *target);
  void CheckSpriteHit(int p);
  void EndRL();
  void DoLine();

  uint8 *MMC5BGVRAMADR(uint32 V);

  template<bool PPUT_MMC5, bool PPUT_MMC5SP, bool PPUT_HOOK, bool PPUT_MMC5CHR1>
  std::pair<uint32, uint8 *> PPUTile(const int X1, uint8 *P, 
				     const uint32 vofs,
				     uint32 refreshaddr_local);

  int ppudead = 1;
  int cycle_parity = 0;

  uint8 VRAMBuffer = 0, PPUGenLatch = 0;

  // Color deemphasis emulation.
  uint8 deemp = 0;
  int deempcnt[8] = {};

  uint8 vtoggle = 0;
  uint8 XOffset = 0;
  
  uint32 TempAddr = 0;
  uint32 RefreshAddr = 0;
  uint16 TempAddrT = 0, RefreshAddrT = 0;
  
  // Perhaps should be compile-time constant.
  int maxsprites = 8;

  // These two used to not be saved in stateinfo, but that caused execution
  // to diverge in 'Ultimate Basketball'.
  int32 sphitx = 0;
  uint8 sphitdata = 0;

  uint32 scanlines_per_frame = 0;
  
  uint8 PPUSPL = 0;

  uint8 *Pline = nullptr, *Plinef = nullptr;
  int firsttile = 0;
  int linestartts = 0;
  int tofix = 0;
  uint8 sprlinebuf[256 + 8] = {};

  // Any sprites on this line? Then this will be set to 1.
  // Needed for zapper emulation and sprite emulation.
  int any_sprites_on_line = 0;

  // These used to be static inside RefreshLine, but interleavings of
  // save/restore in "Ultimate Basketball" can cause execution to diverge.
  // Now saved in stateinfo.
  uint32 pshift[2] = {};
  // This was also static; why not save it too? -tom7
  uint32 atlatch = 0;
  
  // Only used within RefreshLine, used to be static.
  int norecurse = 0;

  uint8 numsprites = 0, SpriteBlurp = 0;

  FC *fc = nullptr;
};

#endif
