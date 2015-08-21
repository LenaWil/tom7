/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO
 *  Copyright (C) 2002 Xodnizel
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
struct Mapper96 : public CartInterface {
  uint8 reg = 0, ppulatch = 0;

  void Sync() {
    fc->cart->setmirror(MI_0);
    fc->cart->setprg32(0x8000, reg & 3);
    fc->cart->setchr4(0x0000, (reg & 4) | ppulatch);
    fc->cart->setchr4(0x1000, (reg & 4) | 3);
  }

  void M96Write(DECLFW_ARGS) {
    reg = V;
    Sync();
  }

  void M96Hook(uint32 A) {
    if ((A & 0x3000) == 0x2000) {
      ppulatch = (A >> 8) & 3;
      Sync();
    }
  }

  void Power() override {
    reg = ppulatch = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xffff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
      ((Mapper96*)fc->fceu->cartiface)->M96Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper96*)fc->fceu->cartiface)->Sync();
  }

  Mapper96(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->PPU_hook = [](FC *fc, uint32 a) {
      ((Mapper96*)fc->fceu->cartiface)->M96Hook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}, {&ppulatch, 1, "PPUL"}});
  }

};
}

CartInterface *Mapper96_Init(FC *fc, CartInfo *info) {
  return new Mapper96(fc, info);
}
