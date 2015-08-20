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
struct Mapper99 : public CartInterface {
  uint8 latch = 0;
  writefunc old4016 = nullptr;

  void Sync() {
    fc->cart->setchr8((latch >> 2) & 1);
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setprg8(0x8000, latch & 4); /* Special for VS Gumshoe */
  }

  void M99Write(DECLFW_ARGS) {
    latch = V;
    Sync();
    old4016(DECLFW_FORWARD);
  }

  void Power() override {
    latch = 0;
    Sync();
    old4016 = fc->fceu->GetWriteHandler(0x4016);
    fc->fceu->SetWriteHandler(0x4016, 0x4016, [](DECLFW_ARGS) {
      ((Mapper99*)fc->fceu->cartiface)->M99Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper99*)fc->fceu->cartiface)->Sync();
  }

  Mapper99(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&latch, 1, "LATC"}});
  }
};
}

CartInterface *Mapper99_Init(FC *fc, CartInfo *info) {
  return new Mapper99(fc, info);
}
