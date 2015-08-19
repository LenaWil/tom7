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
struct Mapper175 : public CartInterface {

  uint8 reg = 0, delay = 0, mirr = 0;

  void Sync() {
    fc->cart->setchr8(reg);
    if (!delay) {
      fc->cart->setprg16(0x8000, reg);
      fc->cart->setprg8(0xC000, reg << 1);
    }
    fc->cart->setprg8(0xE000, (reg << 1) + 1);
    fc->cart->setmirror(((mirr & 4) >> 2) ^ 1);
  }

  void M175Write1(DECLFW_ARGS) {
    mirr = V;
    delay = 1;
    Sync();
  }

  void M175Write2(DECLFW_ARGS) {
    reg = V & 0x0F;
    delay = 1;
    Sync();
  }

  DECLFR_RET M175Read(DECLFR_ARGS) {
    if (A == 0xFFFC) {
      delay = 0;
      Sync();
    }
    return Cart::CartBR(DECLFR_FORWARD);
  }

  void Power() override {
    reg = mirr = delay = 0;
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, [](DECLFR_ARGS) {
      return ((Mapper175*)fc->fceu->cartiface)->M175Read(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0x8000, [](DECLFW_ARGS) {
      ((Mapper175*)fc->fceu->cartiface)->M175Write1(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xA000, 0xA000, [](DECLFW_ARGS) {
      ((Mapper175*)fc->fceu->cartiface)->M175Write2(DECLFW_FORWARD);
    });
    Sync();
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper175*)fc->fceu->cartiface)->Sync();
  }

  Mapper175(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}, {&mirr, 1, "MIRR"}});
  }

};
}

CartInterface *Mapper175_Init(FC *fc, CartInfo *info) {
  return new Mapper175(fc, info);
}
