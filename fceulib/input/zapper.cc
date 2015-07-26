/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2002 Xodnizel
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <string.h>
#include <stdlib.h>

#include "share.h"
#include "zapper.h"
#include "../input.h"

namespace {
struct ZAPPER {
  uint32 mzx = 0, mzy = 0, mzb = 0;
  int zap_readbit = 0;
  uint8 bogo = 0;
  int zappo = 0;
  uint64 zaphit = 0;
  uint32 lastInput = 0;
};

struct ZapperBase : public InputC {
  ZapperBase(FC *fc, int w) : InputC(fc), which(w) {
    // memset(&ZD, 0, sizeof(ZAPPER));

    // XXX! Need to register myself to save the bogo state. (But why
    // not all of it?)
    // {&ZD[0].bogo, 1, "ZBG0"},
    // {&ZD[1].bogo, 1, "ZBG1"},

    CHECK(w == 0 || w == 1);
    fc->state->AddExState(&ZD, sizeof(ZAPPER), 0, (w ? "ZBG1" : "ZBG0"));
  }

  inline int CheckColor(int w) {
    CHECK(w == which);
    fc->ppu->FCEUPPU_LineUpdate();

    if ((ZD.zaphit + 100) >=
	(fc->fceu->timestampbase + fc->X->timestamp)) {
      return 0;
    }

    return 1;
  }
  
  void Update(int w, void *data, int arg) override {
    CHECK(w == which);
    
    uint32 *ptr = (uint32 *)data;

    bool newclicked = (ptr[2] & 3) != 0;
    bool oldclicked = (ZD.lastInput) != 0;

    if (ZD.bogo) {
      ZD.bogo--;
    }

    ZD.lastInput = ptr[2] & 3;

    // woah.. this looks like broken bit logic.
    if (newclicked && !oldclicked) {
      ZD.bogo = 5;
      ZD.mzb = ptr[2];
      ZD.mzx = ptr[0];
      ZD.mzy = ptr[1];
    }
  }

  // Was once "ZapperFrapper".
  void SLHook(int w, uint8 *bg, uint8 *spr, uint32 linets,
	      int final) override {
    CHECK(w == which);

    int xs, xe;
    int zx, zy;

    if (!bg) {
      // New line, so reset stuff.
      ZD.zappo = 0;
      return;
    }
    xs = ZD.zappo;
    xe = final;

    zx = ZD.mzx;
    zy = ZD.mzy;

    if (xe > 256) xe = 256;

    if (fc->ppu->scanline >= (zy - 4) &&
	fc->ppu->scanline <= (zy + 4)) {
      while (xs < xe) {
	uint8 a1, a2;
	uint32 sum;
	if (xs <= (zx + 4) && xs >= (zx - 4)) {
	  a1 = bg[xs];
	  if (spr) {
	    a2 = spr[xs];

	    if (!(a2 & 0x80))
	      if (!(a2 & 0x40) || (a1 & 64)) a1 = a2;
	  }
	  a1 &= 63;

	  sum =
	    fc->palette->palo[a1].r +
	    fc->palette->palo[a1].g +
	    fc->palette->palo[a1].b;
	  if (sum >= 100 * 3) {
	    ZD.zaphit =
              ((uint64)linets + (xs + 16) * (fc->fceu->PAL ? 15 : 16)) /
	      48 +
              fc->fceu->timestampbase;
	    goto endo;
	  }
	}
	xs++;
      }
    }
  endo:
    ZD.zappo = final;

    // if this was a miss, clear out the hit
    if (ZD.mzb & 2) ZD.zaphit = 0;
  }

  void Draw(int w, uint8 *buf, int arg) override {
    CHECK(w == which);
    FCEU_DrawGunSight(buf, ZD.mzx, ZD.mzy);
  }

  void Log(int w, MovieRecord *mr) override {
    CHECK(w == which);
    
    mr->zappers[w].x = ZD.mzx;
    mr->zappers[w].y = ZD.mzy;
    mr->zappers[w].b = ZD.mzb;
    mr->zappers[w].bogo = ZD.bogo;
    mr->zappers[w].zaphit = ZD.zaphit;
  }

  void Load(int w, MovieRecord *mr) override {
    CHECK(w == which);
    
    ZD.mzx = mr->zappers[w].x;
    ZD.mzy = mr->zappers[w].y;
    ZD.mzb = mr->zappers[w].b;
    ZD.bogo = mr->zappers[w].bogo;
    ZD.zaphit = mr->zappers[w].zaphit;
  }

  int which;
  ZAPPER ZD;
};

struct ZapperC : public ZapperBase {
  ZapperC(FC *fc, int w) : ZapperBase(fc, w) {}
  
  uint8 Read(int w) override {
    CHECK(w == which);
    
    uint8 ret = 0;
    if (ZD.bogo) ret |= 0x10;
    if (CheckColor(w)) ret |= 0x8;
    return ret;
  }
};

struct ZapperVSC : public ZapperBase {
  ZapperVSC(FC *fc, int w) : ZapperBase(fc, w) {}
  
  uint8 Read(int w) override {
    CHECK(which == w);
    uint8 ret = 0;

    if (ZD.zap_readbit == 4) ret = 1;

    if (ZD.zap_readbit == 7) {
      if (ZD.bogo) ret |= 0x1;
    }
    if (ZD.zap_readbit == 6) {
      if (!CheckColor(w)) ret |= 0x1;
    }
    ZD.zap_readbit++;
    return ret;
  }

  void Strobe(int w) override {
    CHECK(w == which);
    ZD.zap_readbit = 0;
  }
};
}  // namespace

InputC *CreateZapper(FC *fc, int w) {
  if (fc->fceu->GameInfo->type == GIT_VSUNI) {
    return new ZapperVSC(fc, w);
  } else {
    return new ZapperC(fc, w);
  }
}
