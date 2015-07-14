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

static uint8 IRQx;  // autoenable
static uint8 IRQm;  // mode
static uint16 IRQr;  // reload

static DECLFW(Mapper73_write) {
  // printf("$%04x:$%02x\n",A,V);

  switch (A & 0xF000) {
    case 0x8000:
      IRQr &= 0xFFF0;
      IRQr |= (V & 0xF);
      break;
    case 0x9000:
      IRQr &= 0xFF0F;
      IRQr |= (V & 0xF) << 4;
      break;
    case 0xa000:
      IRQr &= 0xF0FF;
      IRQr |= (V & 0xF) << 8;
      break;
    case 0xb000:
      IRQr &= 0x0FFF;
      IRQr |= (V & 0xF) << 12;
      break;
    case 0xc000:
      IRQm = V & 4;
      IRQx = V & 1;
      fceulib__.ines->iNESIRQa = V & 2;
      if (fceulib__.ines->iNESIRQa) {
        if (IRQm) {
          fceulib__.ines->iNESIRQCount &= 0xFFFF;
          fceulib__.ines->iNESIRQCount |= (IRQr & 0xFF);
        } else {
          fceulib__.ines->iNESIRQCount = IRQr;
        }
      }
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xd000:
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      fceulib__.ines->iNESIRQa = IRQx;
      break;

    case 0xf000: ROM_BANK16(0x8000, V); break;
  }
}

static void Mapper73IRQHook(int a) {
  for (int i = 0; i < a; i++) {
    if (!fceulib__.ines->iNESIRQa) return;
    if (IRQm) {
      uint16 temp = fceulib__.ines->iNESIRQCount;
      temp &= 0xFF;
      fceulib__.ines->iNESIRQCount &= 0xFF00;
      if (temp == 0xFF) {
        fceulib__.ines->iNESIRQCount = IRQr;
        fceulib__.ines->iNESIRQCount |= (uint16)(IRQr & 0xFF);
        fceulib__.X->IRQBegin(FCEU_IQEXT);
      } else {
        temp++;
        fceulib__.ines->iNESIRQCount |= temp;
      }
    } else {
      // 16 bit mode
      if (fceulib__.ines->iNESIRQCount == 0xFFFF) {
        fceulib__.ines->iNESIRQCount = IRQr;
        fceulib__.X->IRQBegin(FCEU_IQEXT);
      } else {
        fceulib__.ines->iNESIRQCount++;
      }
    }
  }
}

void Mapper73_init(void) {
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, Mapper73_write);
  fceulib__.X->MapIRQHook = Mapper73IRQHook;
  IRQr = IRQm = IRQx = 0;
}
