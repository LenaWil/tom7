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
struct Mapper91 : public CartInterface {
  uint8 cregs[4] = {}, pregs[2] = {};
  uint8 IRQCount = 0, IRQa = 0;

  void Sync() {
    fc->cart->setprg8(0x8000, pregs[0]);
    fc->cart->setprg8(0xa000, pregs[1]);
    fc->cart->setprg8(0xc000, ~1);
    fc->cart->setprg8(0xe000, ~0);
    fc->cart->setchr2(0x0000, cregs[0]);
    fc->cart->setchr2(0x0800, cregs[1]);
    fc->cart->setchr2(0x1000, cregs[2]);
    fc->cart->setchr2(0x1800, cregs[3]);
  }

  void M91Write0(DECLFW_ARGS) {
    cregs[A & 3] = V;
    Sync();
  }

  void M91Write1(DECLFW_ARGS) {
    switch (A & 3) {
      case 0:
      case 1:
	pregs[A & 1] = V;
	Sync();
	break;
      case 2:
	IRQa = IRQCount = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 3:
	IRQa = 1;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
    }
  }

  void Power() override {
    Sync();
    fc->fceu->SetWriteHandler(0x6000, 0x6fff, [](DECLFW_ARGS) {
      ((Mapper91*)fc->fceu->cartiface)->M91Write0(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x7000, 0x7fff, [](DECLFW_ARGS) {
      ((Mapper91*)fc->fceu->cartiface)->M91Write1(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xffff, Cart::CartBR);
  }

  void M91IRQHook() {
    if (IRQCount < 8 && IRQa) {
      IRQCount++;
      if (IRQCount >= 8) {
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper91*)fc->fceu->cartiface)->Sync();
  }

  Mapper91(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((Mapper91*)fc->fceu->cartiface)->M91IRQHook();
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{cregs, 4, "CREG"},
	                 {pregs, 2, "PREG"},
			 {&IRQa, 1, "IRQA"},
			 {&IRQCount, 1, "IRQC"}});
  }

};
}

CartInterface *Mapper91_Init(FC *fc, CartInfo *info) {
  return new Mapper91(fc, info);
}
