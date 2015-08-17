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
 *
 * Many-in-one hacked mapper crap.
 *
 * Original BNROM is actually AxROM variations without mirroring control,
 * and haven't SRAM on-board, so it must be removed from here
 *
 * Difficult banking is what NINA board doing, most hacks for 34 mapper are
 * NINA hacks, so this is actually 34 mapper
 *
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper34 : public CartInterface {
  uint8 regs[3] = {};
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, regs[0]);
    fc->cart->setchr4(0x0000, regs[1]);
    fc->cart->setchr4(0x1000, regs[2]);
  }

  void M34Write(DECLFW_ARGS) {
    if (A >= 0x8000) {
      regs[0] = V;
    } else {
      switch (A) {
	case 0x7ffd: regs[0] = V; break;
	case 0x7ffe: regs[1] = V; break;
	case 0x7fff: regs[2] = V; break;
      }
    }
    Sync();
  }

  void Power() override {
    regs[0] = regs[1] = 0;
    regs[2] = 1;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7ffc, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7ffc, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xffff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x7ffd, 0xffff, [](DECLFW_ARGS) {
      ((Mapper34*)fc->fceu->cartiface)->M34Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper34*)fc->fceu->cartiface)->Sync();
  }

  Mapper34(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({{regs, 3, "REGS"}});
  }
};
}
  
CartInterface *Mapper34_Init(FC *fc, CartInfo *info) {
  return new Mapper34(fc, info);
}
