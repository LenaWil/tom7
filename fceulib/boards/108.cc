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

struct Mapper108 : public CartInterface {
 uint8 reg = 0;

  void Sync() {
    fc->cart->setprg8(0x6000, reg);
    fc->cart->setprg32(0x8000, ~0);
    fc->cart->setchr8(0);
  }

  void M108Write(DECLFW_ARGS) {
    reg = V;
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    // regular 108
    fc->fceu->SetWriteHandler(0x8000, 0x8FFF, [](DECLFW_ARGS) {
      ((Mapper108*)fc->fceu->cartiface)->M108Write(DECLFW_FORWARD);
    });
    // simplified Kaiser BB Hack
    fc->fceu->SetWriteHandler(0xF000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper108*)fc->fceu->cartiface)->M108Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper108*)fc->fceu->cartiface)->Sync();
  }

  Mapper108(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}});
  }  
};

}

CartInterface *Mapper108_Init(FC *fc, CartInfo *info) {
  return new Mapper108(fc, info);
}

