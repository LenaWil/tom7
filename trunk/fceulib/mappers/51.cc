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

#define mode(fc) GMB_mapbyte1(fc)[0]
#define page(fc) GMB_mapbyte1(fc)[1]

static uint32 Get8K(FC *fc, uint32 A) {
  uint32 bank = (page(fc) << 2) | ((A >> 13) & 1);

  if (A & 0x4000 && !(mode(fc) & 1)) bank |= 0xC;
  if (!(A & 0x8000)) bank |= 0x20;
  if (mode(fc) == 2)
    bank |= 2;
  else
    bank |= (A >> 13) & 2;
  return (bank);
}

static void Synco(FC *fc) {
  if (GMB_mapbyte1(fc)[0] <= 2)
    fceulib__.ines->MIRROR_SET2(1);
  else
    fceulib__.ines->MIRROR_SET2(0);
  for (uint32 x = 0x6000; x < 0x10000; x += 8192) ROM_BANK8(fc, x, Get8K(fc, x));
}

static DECLFW(Write) {
  if (A & 0x8000)
    GMB_mapbyte1(fc)[1] = V & 0xF;
  else
    GMB_mapbyte1(fc)[0] = (GMB_mapbyte1(fc)[0] & 2) | ((V >> 1) & 1);

  if (A & 0x4000)
    GMB_mapbyte1(fc)[0] = (GMB_mapbyte1(fc)[0] & 1) | ((V >> 3) & 2);
  Synco(fc);
}

void Mapper51_init() {
  FC *fc = &fceulib__;
  fceulib__.fceu->SetWriteHandler(0x6000, 0xFFFF, Write);
  fceulib__.fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
  GMB_mapbyte1(fc)[0] = 1;
  GMB_mapbyte1(fc)[1] = 0;
  Synco(&fceulib__);
}
