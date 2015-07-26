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

#include "toprider.h"

namespace {
struct TopRider : public InputCFC {
  using InputCFC::InputCFC;

  uint8 Read(int w, uint8 ret) override {
    if (w) {
      ret |= (bs & 1) << 3;
      ret |= (boop & 1) << 4;
      bs >>= 1;
      boop >>= 1;
      //  puts("Read");
    }
    return ret;
  }

  void Write(uint8 V) override {
    // if(V&0x2)
    bs = bss;
    // printf("Write: %02x\n",V);
    // boop=0xC0;
  }

  void Update(void *data, int arg) override {
    bss = *(uint8 *)data;
    bss |= bss << 8;
    bss |= bss << 8;
  }

  uint32 bs = 0, bss = 0;
  uint32 boop = 0;
};
}  // namespace

InputCFC *CreateTopRider(FC *fc) {
  return new TopRider(fc);
}
