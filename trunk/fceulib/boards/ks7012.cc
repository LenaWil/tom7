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

static constexpr int WRAMSIZE = 8192;

namespace {
struct KS7012 : public CartInterface {
  uint8 reg = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, reg & 1);
    fc->cart->setchr8(0);
  }

  void UNLKS7012Write(DECLFW_ARGS) {
    //  FCEU_printf("bs %04x %02x\n",A,V);
    switch (A) {
      case 0xE0A0:
	reg = 0;
	Sync();
	break;
      case 0xEE36:
	reg = 1;
	Sync();
	break;
    }
  }

  void Power() override {
    reg = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((KS7012*)fc->fceu->cartiface)->UNLKS7012Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    reg = ~0;
    Sync();
  }

  static void StateRestore(FC *fc, int version) {
    ((KS7012*)fc->fceu->cartiface)->Sync();
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  KS7012(FC *fc, CartInfo *info) : CartInterface(fc) {
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}});
  }
};
}
  
CartInterface *UNLKS7012_Init(FC *fc, CartInfo *info) {
  return new KS7012(fc, info);
}
