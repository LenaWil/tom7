/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2003 Xodnizel
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
#include "share.h"

namespace {
struct FamilyTrainer : public InputCFC {
  FamilyTrainer(FC *fc, char side) : InputCFC(fc), side(side) {}
  
  uint8 Read(int w, uint8 ret) override {
    if (w) {
      ret |= FTValR;
    }
    return (ret);
  }

  void Write(uint8 V) override {
    FTValR = 0;

    // printf("%08x\n",FTVal);
    if (!(V & 0x1))
      FTValR = (FTVal >> 8);
    else if (!(V & 0x2))
      FTValR = (FTVal >> 4);
    else if (!(V & 0x4))
      FTValR = FTVal;

    FTValR = (~FTValR) & 0xF;
    if (side == 'B')
      FTValR = ((FTValR & 0x8) >> 3) | ((FTValR & 0x4) >> 1) |
	       ((FTValR & 0x2) << 1) | ((FTValR & 0x1) << 3);
    FTValR <<= 1;
  }

  void Update(void *data, int arg) override {
    FTVal = *(uint32 *)data;
  }

  uint32 FTVal = 0, FTValR = 0;
  char side = '?';
};
}  // namespace

InputCFC *CreateFamilyTrainerA(FC *fc) {
  return new FamilyTrainer(fc, 'A');
}

InputCFC *CreateFamilyTrainerB(FC *fc) {
  return new FamilyTrainer(fc, 'B');
}
