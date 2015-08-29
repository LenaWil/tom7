/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
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
struct Mapper235 : public CartInterface {
  uint16 cmdreg = 0;

  void Sync() {
    if (cmdreg & 0x400)
      fc->cart->setmirror(MI_0);
    else
      fc->cart->setmirror(((cmdreg >> 13) & 1) ^ 1);
    if (cmdreg & 0x800) {
      fc->cart->setprg16(0x8000, ((cmdreg & 0x300) >> 3) |
			 ((cmdreg & 0x1F) << 1) |
			 ((cmdreg >> 12) & 1));
      fc->cart->setprg16(0xC000, ((cmdreg & 0x300) >> 3) |
			 ((cmdreg & 0x1F) << 1) |
			 ((cmdreg >> 12) & 1));
    } else {
      fc->cart->setprg32(0x8000, ((cmdreg & 0x300) >> 4) | (cmdreg & 0x1F));
    }
  }

  void M235Write(DECLFW_ARGS) {
    cmdreg = A;
    Sync();
  }

  void Power() override {
    fc->cart->setchr8(0);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper235*)fc->fceu->cartiface)->M235Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    cmdreg = 0;
    Sync();
  }

  static void M235Restore(FC *fc, int version) {
    ((Mapper235 *)fc->fceu->cartiface)->Sync();
  }

  Mapper235(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = M235Restore;
    fc->state->AddExVec({{&cmdreg, 2, "CREG"}});
  }
};
}

CartInterface *Mapper235_Init(FC *fc, CartInfo *info) {
  return new Mapper235(fc, info);
}
