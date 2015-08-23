/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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
struct Mapper18 : public CartInterface {
  uint8 preg[4] = {}, creg[8] = {};
  uint8 IRQa = 0, mirr = 0;
  int32 IRQCount = 0, IRQLatch = 0;

  void Sync() {
    for (int i = 0; i < 8; i++)
      fc->cart->setchr1(i << 10, creg[i]);
    fc->cart->setprg8(0x8000, preg[0]);
    fc->cart->setprg8(0xA000, preg[1]);
    fc->cart->setprg8(0xC000, preg[2]);
    fc->cart->setprg8(0xE000, ~0);
    if (mirr & 2)
      fc->cart->setmirror(MI_0);
    else
      fc->cart->setmirror(mirr & 1);
  }

  void M18WriteIRQ(DECLFW_ARGS) {
    switch (A & 0xF003) {
      case 0xE000:
	IRQLatch &= 0xFFF0;
	IRQLatch |= (V & 0x0f) << 0x0;
	break;
      case 0xE001:
	IRQLatch &= 0xFF0F;
	IRQLatch |= (V & 0x0f) << 0x4;
	break;
      case 0xE002:
	IRQLatch &= 0xF0FF;
	IRQLatch |= (V & 0x0f) << 0x8;
	break;
      case 0xE003:
	IRQLatch &= 0x0FFF;
	IRQLatch |= (V & 0x0f) << 0xC;
	break;
      case 0xF000:
	IRQCount = IRQLatch;
	break;
      case 0xF001:
	IRQa = V & 1;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xF002:
	mirr = V & 3;
	Sync();
	break;
    }
  }

  void M18WritePrg(DECLFW_ARGS) {
    uint32 i = ((A >> 1) & 1) | ((A - 0x8000) >> 11);
    preg[i] &= (0xF0) >> ((A & 1) << 2);
    preg[i] |= (V & 0xF) << ((A & 1) << 2);
    Sync();
  }

  void M18WriteChr(DECLFW_ARGS) {
    uint32 i = ((A >> 1) & 1) | ((A - 0xA000) >> 11);
    creg[i] &= (0xF0) >> ((A & 1) << 2);
    creg[i] |= (V & 0xF) << ((A & 1) << 2);
    Sync();
  }

  void Power() override {
    preg[0] = 0;
    preg[1] = 1;
    preg[2] = ~1;
    preg[3] = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0x9FFF, [](DECLFW_ARGS) {
	((Mapper18*)fc->fceu->cartiface)->M18WritePrg(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0xA000, 0xDFFF, [](DECLFW_ARGS) {
	((Mapper18*)fc->fceu->cartiface)->M18WriteChr(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0xE000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper18*)fc->fceu->cartiface)->M18WriteIRQ(DECLFW_FORWARD);
      });
  }

  void M18IRQHook(int a) {
    if (IRQa && IRQCount) {
      IRQCount -= a;
      if (IRQCount <= 0) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQCount = 0;
	IRQa = 0;
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper18*)fc->fceu->cartiface)->Sync();
  }

  Mapper18(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper18*)fc->fceu->cartiface)->M18IRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;

    fc->state->AddExVec({{preg, 4, "PREG"},
	                 {creg, 8, "CREG"},
			 {&mirr, 1, "MIRR"},
			 {&IRQa, 1, "IRQA"},
			 {&IRQCount, 4, "IRQC"},
			 {&IRQLatch, 4, "IRQL"}});
  }
};
}

CartInterface *Mapper18_Init(FC *fc, CartInfo *info) {
  return new Mapper18(fc, info);
}
