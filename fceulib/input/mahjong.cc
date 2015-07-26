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
struct Mahjong : public InputCFC {
  using InputCFC::InputCFC;

  uint8 Read(int w, uint8 ret) override {
    if (w) {
      //  ret|=(MRet&1)<<1;
      ret |= ((MRet & 0x80) >> 6) & 2;
      //  MRet>>=1;

      MRet <<= 1;
    }
    return (ret);
  }

  void Write(uint8 v) override {
    /* 1: I-D7, J-D6, K-D5, L-D4, M-D3, Big Red-D2
       2: A-D7, B-D6, C-D5, D-D4, E-D3, F-D2, G-D1, H-D0
       3: Sel-D6, Start-D7, D5, D4, D3, D2, D1
    */
    MRet = 0;

    v >>= 1;
    v &= 3;

    if (v == 3) {
      MRet = (MReal >> 14) & 0x7F;
      // MRet=((MRet&0x1F) |((MRet&0x40)>>1)|((MRet&0x20)<<1)) <<1;
      // //(MReal>>13)&0x7F;
    } else if (v == 2) {
      MRet = MReal & 0xFF;
    } else if (v == 1) {
      MRet = (MReal >> 8) & 0x3F;
    }
    // HSValR=HSVal<<1;
  }

  void Update(void *data, int arg) override {
    MReal = *(uint32 *)data;
    // printf("%08x\n",MReal>>13);
    // HSVal=*(uint8*)data;
  }
  
  uint32 MReal = 0, MRet = 0;
};
}  // namespace

InputCFC *CreateMahjong(FC *fc) {
  return new Mahjong(fc);
}
