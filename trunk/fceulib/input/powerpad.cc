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
struct PowerPad : public InputC {
  PowerPad(FC *fc, int w, char side) : InputC(fc), which(w), side(side) {
  }

  uint8 Read(int w) override {
    CHECK(which == w);
    uint8 ret = 0;
    ret |= ((pprdata >> pprsb) & 1) << 3;
    ret |= ((pprdata >> (pprsb + 8)) & 1) << 4;
    if (pprsb >= 4) {
      ret |= 0x10;
      if (pprsb >= 8) ret |= 0x08;
    }

    pprsb++;
    return ret;
  }

  
  void Strobe(int w) override {
    pprsb = 0;
  }

  void Update(int w, void *data, int arg) override {
    static constexpr const char shifttableA[12] = {8, 9, 0,  1, 11, 7,
						   4, 2, 10, 6, 5,  3};
    static constexpr const char shifttableB[12] = {1, 0,  9, 8, 2, 4,
						   7, 11, 3, 5, 6, 10};
    pprdata = 0;

    if (side == 'A')
      for (int x = 0; x < 12; x++)
	pprdata |= (((*(uint32 *)data) >> x) & 1) << shifttableA[x];
    else
      for (int x = 0; x < 12; x++)
	pprdata |= (((*(uint32 *)data) >> x) & 1) << shifttableB[x];
  }

  int which;
  char side;
  uint32 pprsb = 0, pprdata = 0;
};
}  // namespace

InputC *CreatePowerpadA(FC *fc, int which) {
  return new PowerPad(fc, which, 'A');
}
InputC *CreatePowerpadB(FC *fc, int which) {
  return new PowerPad(fc, which, 'B');
}

