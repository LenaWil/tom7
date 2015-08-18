/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2011 CaH4e3
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
 * FDS Conversion
 *
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct KS7037Base : public CartInterface {
  uint8 reg[8] = {}, cmd = 0;
  uint8 *WRAM = nullptr;

  void UNLKS7037Write(DECLFW_ARGS) {
    switch (A & 0xE001) {
      case 0x8000: cmd = V & 7; break;
      case 0x8001:
	reg[cmd] = V;
	WSync();
	break;
    }
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  virtual void WSync() {}
  
  static void StateRestore(FC *fc, int version) {
    ((KS7037Base*)fc->fceu->cartiface)->WSync();
  }

  KS7037Base(FC *fc, CartInfo *info) : CartInterface(fc) {
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    // Maybe wasn't present for LH10, but why not?
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&cmd, 1, "CMD0"}, {reg, 8, "REGS"}});
  }
};

struct UNLKS7037 : public KS7037Base {
  using KS7037Base::KS7037Base;

  void WSync() override {
    fc->cart->setprg4r(0x10, 0x6000, 0);
    fc->cart->setprg4(0x7000, 15);
    fc->cart->setprg8(0x8000, reg[6]);
    fc->cart->setprg4(0xA000, ~3);
    fc->cart->setprg4r(0x10, 0xB000, 1);
    fc->cart->setprg8(0xC000, reg[7]);
    fc->cart->setprg8(0xE000, ~0);
    fc->cart->setchr8(0);
    fc->cart->setmirrorw(reg[2] & 1, reg[4] & 1, reg[3] & 1, reg[5] & 1);
  }
  
  void Power() override {
    reg[0] = reg[1] = reg[2] = reg[3] = reg[4] = reg[5] = reg[6] = reg[7] = 0;
    WSync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0x8000, 0x9FFF, [](DECLFW_ARGS) {
      ((UNLKS7037*)fc->fceu->cartiface)->UNLKS7037Write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xA000, 0xBFFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0xC000, 0xFFFF, [](DECLFW_ARGS) {
      ((UNLKS7037*)fc->fceu->cartiface)->UNLKS7037Write(DECLFW_FORWARD);
    });
  }

};

struct LH10 : public KS7037Base {
  using KS7037Base::KS7037Base;

  void WSync() override {
    fc->cart->setprg8(0x6000, ~1);
    fc->cart->setprg8(0x8000, reg[6]);
    fc->cart->setprg8(0xA000, reg[7]);
    fc->cart->setprg8r(0x10, 0xC000, 0);
    fc->cart->setprg8(0xE000, ~0);
    fc->cart->setchr8(0);
    fc->cart->setmirror(0);
  }
  
  void Power() override {
    reg[0] = reg[1] = reg[2] = reg[3] = reg[4] = reg[5] = reg[6] = reg[7] = 0;
    WSync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
      ((LH10*)fc->fceu->cartiface)->UNLKS7037Write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xC000, 0xDFFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0xE000, 0xFFFF, [](DECLFW_ARGS) {
      ((LH10*)fc->fceu->cartiface)->UNLKS7037Write(DECLFW_FORWARD);
    });
  }

};
}

CartInterface *UNLKS7037_Init(FC *fc, CartInfo *info) {
  return new UNLKS7037(fc, info);
}

CartInterface *LH10_Init(FC *fc, CartInfo *info) {
  return new LH10(fc, info);
}
