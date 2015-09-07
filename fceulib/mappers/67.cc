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

#define suntoggle GMB_mapbyte1(fc)[0]

static DECLFW(Mapper67_write) {
  A &= 0xF800;
  if ((A & 0x800) && A <= 0xb800) {
    VROM_BANK2(fc, (A - 0x8800) >> 1, V);
  } else {
    switch (A) {
    case 0xc800:
    case 0xc000:
      if (!suntoggle) {
	fc->ines->iNESIRQCount &= 0xFF;
	fc->ines->iNESIRQCount |= V << 8;
      } else {
	fc->ines->iNESIRQCount &= 0xFF00;
	fc->ines->iNESIRQCount |= V;
      }
      suntoggle ^= 1;
      break;
    case 0xd800:
      suntoggle = 0;
      fc->ines->iNESIRQa = V & 0x10;
      fc->X->IRQEnd(FCEU_IQEXT);
      break;

    case 0xe800:
      switch (V & 3) {
      case 0: fc->ines->MIRROR_SET2(1); break;
      case 1: fc->ines->MIRROR_SET2(0); break;
      case 2: fc->ines->onemir(0); break;
      case 3: fc->ines->onemir(1); break;
      }
      break;
    case 0xf800: ROM_BANK16(fc, 0x8000, V); break;
    }
  }
}

static void SunIRQHook(FC *fc, int a) {
  if (fc->ines->iNESIRQa) {
    fc->ines->iNESIRQCount -= a;
    if (fc->ines->iNESIRQCount <= 0) {
      fc->X->IRQBegin(FCEU_IQEXT);
      fc->ines->iNESIRQa = 0;
      fc->ines->iNESIRQCount = 0xFFFF;
    }
  }
}

MapInterface *Mapper67_init(FC *fc) {
  fc->fceu->SetWriteHandler(0x8000, 0xffff, Mapper67_write);
  fc->X->MapIRQHook = SunIRQHook;
  return new MapInterface(fc);
}
