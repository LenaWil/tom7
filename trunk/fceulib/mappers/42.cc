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
struct Mapper42 : public MapInterface {
  using MapInterface::MapInterface;
  
  void Mapper42_write(DECLFW_ARGS) {
    // FCEU_printf("%04x:%04x\n",A,V);
    switch (A & 0xe003) {
    case 0x8000: VROM_BANK8(fc, V); break;
    case 0xe000:
      GMB_mapbyte1(fc)[0] = V;
      ROM_BANK8(fc, 0x6000, V & 0xF);
      break;
    case 0xe001: fc->ines->MIRROR_SET((V >> 3) & 1); break;
    case 0xe002:
      fc->ines->iNESIRQa = V & 2;
      if (!fc->ines->iNESIRQa) fc->ines->iNESIRQCount = 0;
      fc->X->IRQEnd(FCEU_IQEXT);
      break;
    }
  }

  void Mapper42IRQ(int a) {
    if (fc->ines->iNESIRQa) {
      fc->ines->iNESIRQCount += a;
      if (fc->ines->iNESIRQCount >= 32768)
	fc->ines->iNESIRQCount -= 32768;
      if (fc->ines->iNESIRQCount >= 24576)
	fc->X->IRQBegin(FCEU_IQEXT);
      else
	fc->X->IRQEnd(FCEU_IQEXT);
    }
  }

  void StateRestore(int version) override {
    ROM_BANK8(fc, 0x6000, GMB_mapbyte1(fc)[0] & 0xF);
  }
};
}
  
MapInterface *Mapper42_init(FC *fc) {
  ROM_BANK8(fc, 0x6000, 0);
  ROM_BANK32(fc, ~0);
  fc->fceu->SetWriteHandler(0x6000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper42*)fc->fceu->mapiface)->Mapper42_write(DECLFW_FORWARD);
  });
  fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper42 *)fc->fceu->mapiface)->Mapper42IRQ(a);
  };
  return new Mapper42(fc);
}
