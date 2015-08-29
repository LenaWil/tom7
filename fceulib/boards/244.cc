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

static constexpr uint8 prg_perm[4][4] = {
  {0, 1, 2, 3,},
  {3, 2, 1, 0,},
  {0, 2, 1, 3,},
  {3, 1, 2, 0,},
};

static constexpr uint8 chr_perm[8][8] = {
  {0, 1, 2, 3, 4, 5, 6, 7,},
  {0, 2, 1, 3, 4, 6, 5, 7,},
  {0, 1, 4, 5, 2, 3, 6, 7,},
  {0, 4, 1, 5, 2, 6, 3, 7,},
  {0, 4, 2, 6, 1, 5, 3, 7,},
  {0, 2, 4, 6, 1, 3, 5, 7,},
  {7, 6, 5, 4, 3, 2, 1, 0,},
  {7, 6, 5, 4, 3, 2, 1, 0,},
};

namespace {
struct Mapper244 : public CartInterface {
  uint8 preg = 0, creg = 0;

  void Sync() {
    fc->cart->setprg32(0x8000, preg);
    fc->cart->setchr8(creg);
  }

  void M244Write(DECLFW_ARGS) {
    if (V & 8)
      creg = chr_perm[(V >> 4) & 7][V & 7];
    else
      preg = prg_perm[(V >> 4) & 3][V & 3];
    Sync();
  }

  void Power() override {
    preg = creg = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper244*)fc->fceu->cartiface)->M244Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper244 *)fc->fceu->cartiface)->Sync();
  }

  Mapper244(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{&preg, 1, "PREG"}, {&creg, 1, "CREG"}});
    fc->fceu->GameStateRestore = StateRestore;
  }
};
}

CartInterface *Mapper244_Init(FC *fc, CartInfo *info) {
  return new Mapper244(fc, info);
}
