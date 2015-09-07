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
struct Mapper50 : public MapInterface {
  using MapInterface::MapInterface;
  void Mapper50IRQ(int a) {
    if (fc->ines->iNESIRQa) {
      if (fc->ines->iNESIRQCount < 4096) {
	fc->ines->iNESIRQCount += a;
      } else {
	fc->ines->iNESIRQa = 0;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  void StateRestore(int version) override {
    fc->cart->setprg8(0xc000, GMB_mapbyte1(fc)[0]);
  }

  void M50W(DECLFW_ARGS) {
    if ((A & 0xD060) == 0x4020) {
      if (A & 0x100) {
	fc->ines->iNESIRQa = V & 1;
	if (!fc->ines->iNESIRQa) fc->ines->iNESIRQCount = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
      } else {
	V = ((V & 1) << 2) | ((V & 2) >> 1) | ((V & 4) >> 1) | (V & 8);
	GMB_mapbyte1(fc)[0] = V;
	fc->cart->setprg8(0xc000, V);
      }
    }
  }
};
}
  
MapInterface *Mapper50_init(FC *fc) {
  fc->fceu->SetWriteHandler(0x4020, 0x5fff, [](DECLFW_ARGS) {
    ((Mapper50*)fc->fceu->mapiface)->M50W(DECLFW_FORWARD);
  });
  fc->fceu->SetReadHandler(0x6000, 0xffff, Cart::CartBR);
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper50 *)fc->fceu->mapiface)->Mapper50IRQ(a);
  };

  fc->cart->setprg8(0x6000, 0xF);
  fc->cart->setprg8(0x8000, 0x8);
  fc->cart->setprg8(0xa000, 0x9);
  fc->cart->setprg8(0xc000, 0x0);
  fc->cart->setprg8(0xe000, 0xB);
  return new Mapper50(fc);
}
