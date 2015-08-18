/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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
struct UNLKS7032 : public CartInterface {
  uint8 reg[8] = {}, cmd = 0, IRQa = 0, isirqused = 0;
  int32 IRQCount = 0;

  void Sync() {
    fc->cart->setprg8(0x6000, reg[4]);
    fc->cart->setprg8(0x8000, reg[1]);
    fc->cart->setprg8(0xA000, reg[2]);
    fc->cart->setprg8(0xC000, reg[3]);
    fc->cart->setprg8(0xE000, ~0);
    fc->cart->setchr8(0);
  }

  void UNLKS7032Write(DECLFW_ARGS) {
    //  FCEU_printf("bs %04x %02x\n",A,V);
    switch (A & 0xF000) {
      //    case 0x8FFF: reg[4]=V; Sync(); break;
      case 0x8000:
	fc->X->IRQEnd(FCEU_IQEXT);
	IRQCount = (IRQCount & 0x000F) | (V & 0x0F);
	isirqused = 1;
	break;
      case 0x9000:
	fc->X->IRQEnd(FCEU_IQEXT);
	IRQCount = (IRQCount & 0x00F0) | ((V & 0x0F) << 4);
	isirqused = 1;
	break;
      case 0xA000:
	fc->X->IRQEnd(FCEU_IQEXT);
	IRQCount = (IRQCount & 0x0F00) | ((V & 0x0F) << 8);
	isirqused = 1;
	break;
      case 0xB000:
	fc->X->IRQEnd(FCEU_IQEXT);
	IRQCount = (IRQCount & 0xF000) | (V << 12);
	isirqused = 1;
	break;
      case 0xC000:
	if (isirqused) {
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQa = 1;
	}
	break;
      case 0xE000: cmd = V & 7; break;
      case 0xF000:
	reg[cmd] = V;
	Sync();
	break;
    }
  }

  void UNLSMB2JIRQHook(int a) {
    if (IRQa) {
      IRQCount += a;
      if (IRQCount >= 0xFFFF) {
	IRQa = 0;
	IRQCount = 0;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4020, 0xFFFF, [](DECLFW_ARGS) {
      ((UNLKS7032*)fc->fceu->cartiface)->UNLKS7032Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLKS7032*)fc->fceu->cartiface)->Sync();
  }

  UNLKS7032(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((UNLKS7032*)fc->fceu->cartiface)->UNLSMB2JIRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&cmd, 1, "CMD0"},
	                 {reg, 8, "REGS"},
			 {&IRQa, 1, "IRQA"},
			 {&IRQCount, 4, "IRQC"}});
  }

};
}

CartInterface *UNLKS7032_Init(FC *fc, CartInfo *info) {
  return new UNLKS7032(fc, info);
}
