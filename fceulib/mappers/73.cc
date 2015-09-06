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

namespace {
struct Mapper73 : public MapInterface {
  using MapInterface::MapInterface;

  uint8 IRQx = 0;  // autoenable
  uint8 IRQm = 0;  // mode
  uint16 IRQr = 0;  // reload

  void Mapper73_write(DECLFW_ARGS) {
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
      fc->ines->iNESIRQa = V & 2;
      if (fc->ines->iNESIRQa) {
	if (IRQm) {
	  fc->ines->iNESIRQCount &= 0xFFFF;
	  fc->ines->iNESIRQCount |= (IRQr & 0xFF);
	} else {
	  fc->ines->iNESIRQCount = IRQr;
	}
      }
      fc->X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xd000:
      fc->X->IRQEnd(FCEU_IQEXT);
      fc->ines->iNESIRQa = IRQx;
      break;

    case 0xf000: ROM_BANK16(fc, 0x8000, V); break;
    }
  }

  void Mapper73IRQHook(int a) {
    for (int i = 0; i < a; i++) {
      if (!fc->ines->iNESIRQa) return;
      if (IRQm) {
	uint16 temp = fc->ines->iNESIRQCount;
	temp &= 0xFF;
	fc->ines->iNESIRQCount &= 0xFF00;
	if (temp == 0xFF) {
	  fc->ines->iNESIRQCount = IRQr;
	  fc->ines->iNESIRQCount |= (uint16)(IRQr & 0xFF);
	  fc->X->IRQBegin(FCEU_IQEXT);
	} else {
	  temp++;
	  fc->ines->iNESIRQCount |= temp;
	}
      } else {
	// 16 bit mode
	if (fc->ines->iNESIRQCount == 0xFFFF) {
	  fc->ines->iNESIRQCount = IRQr;
	  fc->X->IRQBegin(FCEU_IQEXT);
	} else {
	  fc->ines->iNESIRQCount++;
	}
      }
    }
  }
};
}
  
MapInterface *Mapper73_init(FC *fc) {
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper73 *)fc->fceu->mapiface)->Mapper73_write(DECLFW_FORWARD);
  });
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper73 *)fc->fceu->mapiface)->Mapper73IRQHook(a);
  };
  return new Mapper73(fc);
}
