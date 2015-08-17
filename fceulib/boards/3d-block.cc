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
struct UNL3D : public CartInterface {
  uint8 reg[4] = {}, IRQa = 0;
  int16 IRQCount = 0, IRQPause = 0;

  int16 Count = 0x0000;
  //#define Count 0x1800
  #define Pause 0x010

  void Sync() {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(0);
  }

  void UNL3DBlockWrite(DECLFW_ARGS) {
    switch (A) {
      // 4800 32
      // 4900 37
      // 4a00 01
      // 4e00 18
      case 0x4800: reg[0] = V; break;
      case 0x4900: reg[1] = V; break;
      case 0x4a00: reg[2] = V; break;
      case 0x4e00:
	reg[3] = V;
	IRQCount = Count;
	IRQPause = Pause;
	IRQa = 1;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
    }
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4800, 0x4E00, [](DECLFW_ARGS) {
      ((UNL3D*)fc->fceu->cartiface)->UNL3DBlockWrite(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    Count += 0x10;
    // FCEU_printf("Count=%04x\n", Count);
  }

  void UNL3DBlockIRQHook(int a) {
    if (IRQa) {
      if (IRQCount > 0) {
	IRQCount -= a;
      } else {
	if (IRQPause > 0) {
	  IRQPause -= a;
	  fc->X->IRQBegin(FCEU_IQEXT);
	} else {
	  IRQCount = Count;
	  IRQPause = Pause;
	  fc->X->IRQEnd(FCEU_IQEXT);
	}
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((UNL3D*)fc->fceu->cartiface)->Sync();
  }

  UNL3D(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((UNL3D*)fc->fceu->cartiface)->UNL3DBlockIRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{reg, 4, "REGS"}, {&IRQa, 1, "IRQA"}, {&IRQCount, 2, "IRQC"}});
  }
};
}
  
CartInterface *UNL3DBlock_Init(FC *fc, CartInfo *info) {
  return new UNL3D(fc, info);
}
