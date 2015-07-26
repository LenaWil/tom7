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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include <string.h>
#include <stdlib.h>

#include "share.h"

namespace {
struct ZAPPER {
  uint32 mzx = 0, mzy = 0, mzb = 0;
  int zap_readbit = 0;
  int bogo = 0;
  int zappo = 0;
  uint64 zaphit = 0;
};

struct SpaceShadow : public InputCFC {
  SpaceShadow(FC *fc) : InputCFC(fc) {}

  // nee "ZapperFrapper"
  void SLHook(uint8 *bg, uint8 *spr, uint32 linets, int final) override {
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

    if (fc->ppu->scanline >= (zy - 4) && fc->ppu->scanline <= (zy + 4)) {
      while (xs < xe) {
        uint8 a1, a2;
        uint32 sum;
        if (xs <= (zx + 4) && xs >= (zx - 4)) {
          a1 = bg[xs];
          if (spr) {
            a2 = spr[xs];

            if (!(a2 & 0x80)) {
              if (!(a2 & 0x40) || (a1 & 64)) {
                a1 = a2;
              }
            }
          }
          a1 &= 63;

          sum = fc->palette->palo[a1].r + fc->palette->palo[a1].g +
                fc->palette->palo[a1].b;
          if (sum >= 100 * 3) {
            ZD.zaphit =
                ((uint64)linets + (xs + 16) * (fc->fceu->PAL ? 15 : 16)) / 48 +
                fc->fceu->timestampbase;
            goto endo;
          }
        }
        xs++;
      }
    }
  endo:
    ZD.zappo = final;
  }

  inline int CheckColor() {
    fc->ppu->FCEUPPU_LineUpdate();
    return !((ZD.zaphit + 10) >= (fc->fceu->timestampbase + fc->X->timestamp));
  }

  uint8 Read(int w, uint8 ret) override {
    if (w) {
      ret &= ~0x18;
      if (ZD.bogo) ret |= 0x10;
      if (CheckColor()) ret |= 0x8;
    } else {
      // printf("Kayo: %d\n",ZD.zap_readbit);
      ret &= ~2;
      // if (ZD.zap_readbit==4) ret|=ZD.mzb&2;
      ret |= (ret & 1) << 1;
      // ZD.zap_readbit++;
    }
    return ret;
  }

  void Draw(uint8 *buf, int arg) override {
    FCEU_DrawCursor(buf, ZD.mzx, ZD.mzy);
  }

  void Update(void *data, int arg) override {
    uint32 *ptr = (uint32 *)data;

    if (ZD.bogo) ZD.bogo--;
    if (ptr[2] & 1 && (!(ZD.mzb & 1))) ZD.bogo = 5;

    ZD.mzx = ptr[0];
    ZD.mzy = ptr[1];
    ZD.mzb = ptr[2];
  }

  void Strobe() override { ZD.zap_readbit = 0; }

  ZAPPER ZD;
};
}  // namespace

InputCFC *CreateSpaceShadow(FC *fc) {
  return new SpaceShadow(fc);
}
