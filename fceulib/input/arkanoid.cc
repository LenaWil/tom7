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

#include "arkanoid.h"

namespace {
struct ARK {
  uint32 mzx = 0, mzb = 0;
  uint32 readbit = 0;
};

static uint32 FixX(uint32 x) {
  x = 98 + x * 144 / 240;
  if (x > 242) x = 242;
  x = ~x;
  return x;
}

struct Arkanoid : public InputC {
  Arkanoid(FC *fc, int w) : InputC(fc) {
    NESArk[w].mzx = 98;
    NESArk[w].mzb = 0;
  }

  uint8 Read(int w) override {
    uint8 ret = 0;

    if (NESArk[w].readbit >= 8) {
      ret |= 1 << 4;
    } else {
      ret |= ((NESArk[w].mzx >> (7 - NESArk[w].readbit)) & 1) << 4;

      NESArk[w].readbit++;
    }
    ret |= (NESArk[w].mzb & 1) << 3;
    return ret;
  }

  void Strobe(int w) override {
    NESArk[w].readbit = 0;
  }

  void Update(int w, void *data, int arg) override {
    uint32 *ptr = (uint32 *)data;
    NESArk[w].mzx = FixX(ptr[0]);
    NESArk[w].mzb = ptr[2] ? 1 : 0;
  }

  ARK NESArk[2];
};

struct ArkanoidFC : public InputCFC {
  ArkanoidFC(FC *fc) : InputCFC(fc) {
    FCArk.mzx = 98;
    FCArk.mzb = 0;
  }

  void Update(void *data, int arg) override {
    uint32 *ptr = (uint32 *)data;
    FCArk.mzx = FixX(ptr[0]);
    FCArk.mzb = ptr[2] ? 1 : 0;
  }

  void Strobe() override {
    FCArk.readbit = 0;
  }

  uint8 Read(int w, uint8 ret) override {
    ret &= ~2;
    
    if (w) {
      if (FCArk.readbit >= 8) {
	ret |= 2;
      } else {
	ret |= ((FCArk.mzx >> (7 - FCArk.readbit)) & 1) << 1;
	
	FCArk.readbit++;
      }
    } else {
      ret |= FCArk.mzb << 1;
    }
    return ret;
  }

  ARK FCArk;
};
}
  
InputC *CreateArkanoid(FC *fc, int w) {
  return new Arkanoid(fc, w);
}

InputCFC *CreateArkanoidFC(FC *fc) {
  return new ArkanoidFC(fc);
}
