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
struct Mapper117 : public CartInterface {
  uint8 prgreg[4] = {}, chrreg[8] = {}, mirror = 0;
  uint8 IRQa = 0, IRQCount = 0, IRQLatch = 0;

  void Sync() {
    fc->cart->setprg8(0x8000, prgreg[0]);
    fc->cart->setprg8(0xa000, prgreg[1]);
    fc->cart->setprg8(0xc000, prgreg[2]);
    fc->cart->setprg8(0xe000, prgreg[3]);
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chrreg[i]);
    fc->cart->setmirror(mirror ^ 1);
  }

  void M117Write(DECLFW_ARGS) {
    if (A < 0x8004) {
      prgreg[A & 3] = V;
      Sync();
    } else if ((A >= 0xA000) && (A <= 0xA007)) {
      chrreg[A & 7] = V;
      Sync();
    } else {
      switch (A) {
	case 0xc001: IRQLatch = V; break;
	case 0xc003:
	  IRQCount = IRQLatch;
	  IRQa |= 2;
	  break;
	case 0xe000:
	  IRQa &= ~1;
	  IRQa |= V & 1;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0xc002: fc->X->IRQEnd(FCEU_IQEXT); break;
	case 0xd000: mirror = V & 1;
      }
    }
  }

  void Power() override {
    prgreg[0] = ~3;
    prgreg[1] = ~2;
    prgreg[2] = ~1;
    prgreg[3] = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper117*)fc->fceu->cartiface)->M117Write(DECLFW_FORWARD);
    });
  }

  void M117IRQHook() {
    if (IRQa == 3 && IRQCount) {
      IRQCount--;
      if (!IRQCount) {
	IRQa &= 1;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper117*)fc->fceu->cartiface)->Sync();
  }

  Mapper117(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((Mapper117*)fc->fceu->cartiface)->M117IRQHook();
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&IRQa, 1, "IRQA"},
	                 {&IRQCount, 1, "IRQC"},
			 {&IRQLatch, 1, "IRQL"},
			 {prgreg, 4, "PREG"},
			 {chrreg, 8, "CREG"},
			 {&mirror, 1, "MREG"}});
  }
};
}
  
CartInterface *Mapper117_Init(FC *fc, CartInfo *info) {
  return new Mapper117(fc, info);
}
