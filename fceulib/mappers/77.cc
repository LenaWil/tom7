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

/* Original code provided by LULU */

static DECLFW(Mapper77_write) {
  GMB_mapbyte1(fc)[0] = V;
  ROM_BANK32(fc, V & 0x7);
  VROM_BANK2(fc, 0x0000, (V & 0xf0) >> 4);
}

static void Mapper77_StateRestore(int version) {
  FC *fc = &fceulib__;
  if (version >= 7200) {
    ROM_BANK32(&fceulib__, GMB_mapbyte1(fc)[0] & 0x7);
    VROM_BANK2(&fceulib__, 0x0000, (GMB_mapbyte1(fc)[0] & 0xf0) >> 4);
  }
  for (int x = 2; x < 8; x++) VRAM_BANK1(&fceulib__, x * 0x400, x);
}

void Mapper77_init() {
  int x;

  ROM_BANK32(&fceulib__, 0);
  for (x = 2; x < 8; x++) VRAM_BANK1(&fceulib__, x * 0x400, x);
  fceulib__.fceu->SetWriteHandler(0x6000, 0xffff, Mapper77_write);
  fceulib__.ines->MapStateRestore = Mapper77_StateRestore;
}
