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

static uint32 lastA;
static int isfu;
static uint8 CCache[8];

static void Fudou_PPU(uint32 A) {
  static int last = -1;
  static uint8 z;

  if (A >= 0x2000) return;

  A >>= 10;
  lastA = A;

  z = CCache[A];
  if (z != last) {
    fceulib__.ines->onemir(z);
    last = z;
  }
}

static void mira() {
  if (isfu) {
    CCache[0] = CCache[1] = mapbyte2[0] >> 7;
    CCache[2] = CCache[3] = mapbyte2[1] >> 7;

    for (int x = 0; x < 4; x++) CCache[4 + x] = mapbyte2[2 + x] >> 7;

    fceulib__.ines->onemir(CCache[lastA]);
  } else {
    fceulib__.ines->MIRROR_SET2(mapbyte1[0] & 1);
  }
}

static DECLFW(Mapper80_write) {
  switch (A) {
  case 0x7ef0:
    mapbyte2[0] = V;
    VROM_BANK2(fc, 0x0000, (V >> 1) & 0x3F);
    mira();
    break;
  case 0x7ef1:
    mapbyte2[1] = V;
    VROM_BANK2(fc, 0x0800, (V >> 1) & 0x3f);
    mira();
    break;

  case 0x7ef2:
    mapbyte2[2] = V;
    VROM_BANK1(fc, 0x1000, V);
    mira();
    break;
  case 0x7ef3:
    mapbyte2[3] = V;
    VROM_BANK1(fc, 0x1400, V);
    mira();
    break;
  case 0x7ef4:
    mapbyte2[4] = V;
    VROM_BANK1(fc, 0x1800, V);
    mira();
    break;
  case 0x7ef5:
    mapbyte2[5] = V;
    VROM_BANK1(fc, 0x1c00, V);
    mira();
    break;
  case 0x7ef6:
    mapbyte1[0] = V;
    mira();
    break;
  case 0x7efa:
  case 0x7efb: ROM_BANK8(fc, 0x8000, V); break;
  case 0x7efd:
  case 0x7efc: ROM_BANK8(fc, 0xA000, V); break;
  case 0x7efe:
  case 0x7eff: ROM_BANK8(fc, 0xC000, V); break;
  }
}

static void Restore(int version) {
  mira();
}

void Mapper80_init() {
  // 7f00-7fff battery backed ram inside mapper chip,
  // controlled by 7ef8 register, A8 - enable, FF - disable (?)
  fceulib__.fceu->SetWriteHandler(0x4020, 0x7eff, Mapper80_write);
  fceulib__.ines->MapStateRestore = Restore;
  isfu = 0;
}

void Mapper207_init() {
  Mapper80_init();
  isfu = 1;
  fceulib__.ppu->PPU_hook = Fudou_PPU;
}
