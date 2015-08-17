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
 */

#include "mapinc.h"

namespace {
struct KS7013 : public CartInterface {
  uint8 reg = 0, mirr = 0;

  void Sync() {
    fc->cart->setprg16(0x8000, reg);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setmirror(mirr);
    fc->cart->setchr8(0);
  }

  void UNLKS7013BLoWrite(DECLFW_ARGS) {
    reg = V;
    Sync();
  }

  void UNLKS7013BHiWrite(DECLFW_ARGS) {
    mirr = (V & 1) ^ 1;
    Sync();
  }

  void Power() override {
    reg = 0;
    mirr = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      ((KS7013*)fc->fceu->cartiface)->UNLKS7013BLoWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((KS7013*)fc->fceu->cartiface)->UNLKS7013BHiWrite(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    reg = 0;
    Sync();
  }

  static void StateRestore(FC *fc, int version) {
    ((KS7013*)fc->fceu->cartiface)->Sync();
  }

  KS7013(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}, {&mirr, 1, "MIRR"}});
  }
};
}
  
CartInterface *UNLKS7013B_Init(FC *fc, CartInfo *info) {
  return new KS7013(fc, info);
}
