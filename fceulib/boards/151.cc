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
struct Mapper151 : public CartInterface {
  uint8 regs[8] = {};

  void Sync() {
    fc->cart->setprg8(0x8000, regs[0]);
    fc->cart->setprg8(0xA000, regs[2]);
    fc->cart->setprg8(0xC000, regs[4]);
    fc->cart->setprg8(0xE000, ~0);
    fc->cart->setchr4(0x0000, regs[6]);
    fc->cart->setchr4(0x1000, regs[7]);
  }

  void M151Write(DECLFW_ARGS) {
    regs[(A >> 12) & 7] = V;
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper151*)fc->fceu->cartiface)->M151Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper151*)fc->fceu->cartiface)->Sync();
  }

  Mapper151(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{regs, 8, "REGS"}});
  }

};
}

CartInterface *Mapper151_Init(FC *fc, CartInfo *info) {
  return new Mapper151(fc, info);
}
