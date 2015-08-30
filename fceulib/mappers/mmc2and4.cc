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

#include "mapinc.h"

#define MMC4reg GMB_mapbyte1(fc)
#define latcha1 GMB_mapbyte2(fc)[0]
#define latcha2 GMB_mapbyte2(fc)[1]

static void latchcheck(FC *fc, uint32 VAddr) {
  uint8 h = VAddr >> 8;

  if (h >= 0x20 || ((h & 0xF) != 0xF)) return;

  uint8 l = VAddr & 0xF0;

  if (h < 0x10) {
    if (l == 0xD0) {
      VROM_BANK4(&fceulib__, 0x0000, MMC4reg[0]);
      latcha1 = 0xFD;
    } else if (l == 0xE0) {
      VROM_BANK4(&fceulib__, 0x0000, MMC4reg[1]);
      latcha1 = 0xFE;
    }
  } else {
    if (l == 0xD0) {
      VROM_BANK4(&fceulib__, 0x1000, MMC4reg[2]);
      latcha2 = 0xFD;
    } else if (l == 0xE0) {
      VROM_BANK4(&fceulib__, 0x1000, MMC4reg[3]);
      latcha2 = 0xFE;
    }
  }
}

// $Axxx
DECLFW(Mapper9_write) {
  ROM_BANK8(fc, 0x8000, V);
}

DECLFW(Mapper10_write) {
  ROM_BANK16(fc, 0x8000, V);
}

DECLFW(Mapper9and10_write) {
  switch (A & 0xF000) {
  case 0xB000:
    if (latcha1 == 0xFD) {
      VROM_BANK4(fc, 0x0000, V);
    }
    MMC4reg[0] = V;
    break;
  case 0xC000:
    if (latcha1 == 0xFE) {
      VROM_BANK4(fc, 0x0000, V);
    }
    MMC4reg[1] = V;
    break;
  case 0xD000:
    if (latcha2 == 0xFD) {
      VROM_BANK4(fc, 0x1000, V);
    }
    MMC4reg[2] = V;
    break;
  case 0xE000:
    if (latcha2 == 0xFE) {
      VROM_BANK4(fc, 0x1000, V);
    }
    MMC4reg[3] = V;
    break;
  case 0xF000:
    fceulib__.ines->MIRROR_SET(V & 1);
    break;
  }
}

void Mapper9_init() {
  FC *fc = &fceulib__;
  latcha1 = 0xFE;
  latcha2 = 0xFE;
  ROM_BANK8(&fceulib__, 0xA000, ~2);
  ROM_BANK8(&fceulib__, 0x8000, 0);
  fceulib__.fceu->SetWriteHandler(0xA000, 0xAFFF, Mapper9_write);
  fceulib__.fceu->SetWriteHandler(0xB000, 0xFFFF, Mapper9and10_write);
  fceulib__.ppu->PPU_hook = latchcheck;
}

void Mapper10_init() {
  FC *fc = &fceulib__;
  latcha1 = latcha2 = 0xFE;
  fceulib__.fceu->SetWriteHandler(0xA000, 0xAFFF, Mapper10_write);
  fceulib__.fceu->SetWriteHandler(0xB000, 0xFFFF, Mapper9and10_write);
  fceulib__.ppu->PPU_hook = latchcheck;
}
