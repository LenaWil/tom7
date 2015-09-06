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
struct Mapper40 : public MapInterface {
  using MapInterface::MapInterface;

  void Mapper40_write(DECLFW_ARGS) {
    switch (A & 0xe000) {
    case 0x8000:
      fc->ines->iNESIRQa = 0;
      fc->ines->iNESIRQCount = 0;
      fc->X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xa000: fc->ines->iNESIRQa = 1; break;
    case 0xe000: ROM_BANK8(fc, 0xc000, V & 7); break;
    }
  }

  void Mapper40IRQ(int a) {
    if (fc->ines->iNESIRQa) {
      if (fc->ines->iNESIRQCount < 4096) {
	fc->ines->iNESIRQCount += a;
      } else {
	fc->ines->iNESIRQa = 0;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }
};
}
  
MapInterface *Mapper40_init(FC *fc) {
  Mapper40 *m = new Mapper40(fc);
  ROM_BANK8(fc, 0x6000, (~0) - 1);
  ROM_BANK8(fc, 0x8000, (~0) - 3);
  ROM_BANK8(fc, 0xa000, (~0) - 2);
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper40*)fc->fceu->mapiface)->Mapper40_write(DECLFW_FORWARD);
  });
  fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper40 *)fc->fceu->mapiface)->Mapper40IRQ(a);
  };
  return m;
}
