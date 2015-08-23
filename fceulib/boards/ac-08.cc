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
struct AC08 : public CartInterface {
  uint8 reg = 0, mirr = 0;

  void Sync() {
    fc->cart->setprg8(0x6000, reg);
    fc->cart->setprg32r(1, 0x8000, 0);
    fc->cart->setchr8(0);
    fc->cart->setmirror(mirr);
  }

  void AC08Mirr(DECLFW_ARGS) {
    mirr = ((V & 8) >> 3) ^ 1;
    Sync();
  }

  void AC08Write(DECLFW_ARGS) {
    if (A == 0x8001) {
      // Green Berret bank switching is only 100x xxxx xxxx xxx1 mask
      reg = (V >> 1) & 0xf;
    } else {
      // Sad But True, 2-in-1 mapper, Green Berret need value
      // shifted left one byte, Castlevania doesn't
      reg = V & 0xf;
    }
    Sync();
  }

  void Power() override {
    reg = 0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4025, 0x4025, [](DECLFW_ARGS) {
	((AC08*)fc->fceu->cartiface)->AC08Mirr(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((AC08*)fc->fceu->cartiface)->AC08Write(DECLFW_FORWARD);
      });
  }

  static void StateRestore(FC *fc, int version) {
    ((AC08*)fc->fceu->cartiface)->Sync();
  }

  AC08(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}, {&mirr, 1, "MIRR"}});
  }
};
}

CartInterface *AC08_Init(FC *fc, CartInfo *info) {
}
