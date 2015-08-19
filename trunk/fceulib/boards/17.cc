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
struct Mapper17 : public CartInterface {
  uint8 preg[4] = {}, creg[8] = {};
  uint8 IRQa = 0, mirr = 0;
  int32 IRQCount = 0, IRQLatch = 0;

  void Sync() {
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, creg[i]);
    fc->cart->setprg8(0x8000, preg[0]);
    fc->cart->setprg8(0xA000, preg[1]);
    fc->cart->setprg8(0xC000, preg[2]);
    fc->cart->setprg8(0xE000, preg[3]);
    switch (mirr) {
      case 0: fc->cart->setmirror(MI_0); break;
      case 1: fc->cart->setmirror(MI_1); break;
      case 2: fc->cart->setmirror(MI_H); break;
      case 3: fc->cart->setmirror(MI_V); break;
    }
  }

  void M17WriteMirr(DECLFW_ARGS) {
    mirr = ((A << 1) & 2) | ((V >> 4) & 1);
    Sync();
  }

  void M17WriteIRQ(DECLFW_ARGS) {
    switch (A) {
      case 0x4501:
	IRQa = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0x4502:
	IRQCount &= 0xFF00;
	IRQCount |= V;
	break;
      case 0x4503:
	IRQCount &= 0x00FF;
	IRQCount |= V << 8;
	IRQa = 1;
	break;
    }
  }

  void M17WritePrg(DECLFW_ARGS) {
    preg[A & 3] = V;
    Sync();
  }

  void M17WriteChr(DECLFW_ARGS) {
    creg[A & 7] = V;
    Sync();
  }

  void Power() override {
    preg[3] = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x42FE, 0x42FF, [](DECLFW_ARGS) {
      ((Mapper17*)fc->fceu->cartiface)->M17WriteMirr(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4500, 0x4503, [](DECLFW_ARGS) {
      ((Mapper17*)fc->fceu->cartiface)->M17WriteIRQ(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4504, 0x4507, [](DECLFW_ARGS) {
      ((Mapper17*)fc->fceu->cartiface)->M17WritePrg(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4510, 0x4517, [](DECLFW_ARGS) {
      ((Mapper17*)fc->fceu->cartiface)->M17WriteChr(DECLFW_FORWARD);
    });
  }

  void M17IRQHook(int a) {
    if (IRQa) {
      IRQCount += a;
      if (IRQCount >= 0x10000) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
	IRQCount = 0;
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper17*)fc->fceu->cartiface)->Sync();
  }

  Mapper17(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper17*)fc->fceu->cartiface)->M17IRQHook(a);
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

CartInterface *Mapper17_Init(FC *fc, CartInfo *info) {
  return new Mapper17(fc, info);
}
