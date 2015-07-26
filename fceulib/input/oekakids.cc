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

#include "oekakids.h"

namespace {
struct OekaKids : public InputCFC {
  OekaKids(FC *fc) : InputCFC(fc) {
    OKValR = 0;
  }

  uint8 Read(int w, uint8 ret) override {
    if (w) {
      ret |= OKValR;
    }
    return ret;
  }

  void Write(uint8 V) override {
    if (!(V & 0x1)) {
      int32 vx, vy;

      // puts("Redo");
      OKValR = OKData = 0;

      if (OKB) OKData |= 1;

      if (OKY >= 48)
	OKData |= 2;
      else if (OKB)
	OKData |= 3;

      vx = OKX * 240 / 256 + 8;
      vy = OKY * 256 / 240 - 12;
      if (vy < 0) vy = 0;
      if (vy > 255) vy = 255;
      if (vx < 0) vx = 0;
      if (vx > 255) vx = 255;
      OKData |= (vx << 10) | (vy << 2);
    } else {
      if ((~LastWR) & V & 0x02) OKData <<= 1;

      if (!(V & 0x2)) {
	OKValR = 0x4;
      } else {
	if (OKData & 0x40000)
	  OKValR = 0;
	else
	  OKValR = 0x8;
      }
    }
    LastWR = V;
  }

  void Update(void *data, int arg) override {
    // puts("Sync");
    OKX = ((uint32 *)data)[0];
    OKY = ((uint32 *)data)[1];
    OKB = ((uint32 *)data)[2];
  }

  void Draw(uint8 *buf, int arg) override {
    if (OKY < 44) FCEU_DrawCursor(buf, OKX, OKY);
  }
  
  uint8 OKValR = 0, LastWR = 0;
  uint32 OKData = 0;
  uint32 OKX = 0, OKY = 0, OKB = 0;
};

}  // namespace

InputCFC *CreateOekaKids(FC *fc) {
  return new OekaKids(fc);
}
