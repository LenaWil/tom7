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

void IREMIRQHook(int a) {
  if (fceulib__.ines->iNESIRQa) {
    fceulib__.ines->iNESIRQCount -= a;
    if (fceulib__.ines->iNESIRQCount < -4) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      fceulib__.ines->iNESIRQa = 0;
      fceulib__.ines->iNESIRQCount = 0xFFFF;
    }
  }
}

static DECLFW(Mapper65_write) {
  // if(A>=0x9000 && A<=0x9006)
  // printf("$%04x:$%02x, %d\n",A,V,scanline);
  switch (A) {
    // default: printf("$%04x:$%02x\n",A,V);
    //        break;
  case 0x8000:
    ROM_BANK8(fc, 0x8000, V);
    break;
    // case
    // 0x9000:printf("$%04x:$%02x\n",A,V);fceulib__.ines->MIRROR_SET2((V>>6)&1);break;
  case 0x9001: fceulib__.ines->MIRROR_SET(V >> 7); break;
  case 0x9003:
    fceulib__.ines->iNESIRQa = V & 0x80;
    fceulib__.X->IRQEnd(FCEU_IQEXT);
    break;
  case 0x9004:
    fceulib__.ines->iNESIRQCount = fceulib__.ines->iNESIRQLatch;
    break;
  case 0x9005:
    fceulib__.ines->iNESIRQLatch &= 0x00FF;
    fceulib__.ines->iNESIRQLatch |= V << 8;
    break;
  case 0x9006:
    fceulib__.ines->iNESIRQLatch &= 0xFF00;
    fceulib__.ines->iNESIRQLatch |= V;
    break;
  case 0xB000: VROM_BANK1(fc, 0x0000, V); break;
  case 0xB001: VROM_BANK1(fc, 0x0400, V); break;
  case 0xB002: VROM_BANK1(fc, 0x0800, V); break;
  case 0xB003: VROM_BANK1(fc, 0x0C00, V); break;
  case 0xB004: VROM_BANK1(fc, 0x1000, V); break;
  case 0xB005: VROM_BANK1(fc, 0x1400, V); break;
  case 0xB006: VROM_BANK1(fc, 0x1800, V); break;
  case 0xB007: VROM_BANK1(fc, 0x1C00, V); break;
  case 0xa000: ROM_BANK8(fc, 0xA000, V); break;
  case 0xC000: ROM_BANK8(fc, 0xC000, V); break;
  }
  // fceulib__.ines->MIRROR_SET2(1);
}

void Mapper65_init(void) {
  fceulib__.X->MapIRQHook = IREMIRQHook;
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, Mapper65_write);
}
