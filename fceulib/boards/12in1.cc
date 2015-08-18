/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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
struct BMC12IN1 : public CartInterface {
  uint8 reg[4] = {};

  void Sync() {
    uint8 bank = (reg[3] & 3) << 3;
    fc->cart->setchr4(0x0000, (reg[1] >> 3) | (bank << 2));
    fc->cart->setchr4(0x1000, (reg[2] >> 3) | (bank << 2));
    if (reg[3] & 8) {
      fc->cart->setprg32(0x8000, ((reg[2] & 7) >> 1) | bank);
    } else {
      fc->cart->setprg16(0x8000, (reg[1] & 7) | bank);
      fc->cart->setprg16(0xc000, 7 | bank);
    }
    fc->cart->setmirror(((reg[3] & 4) >> 2) ^ 1);
  }

  void BMC12IN1Write(DECLFW_ARGS) {
    switch (A) {
      case 0xafff: reg[0] = V; break;
      case 0xbfff: reg[1] = V; break;
      case 0xdfff: reg[2] = V; break;
      case 0xefff: reg[3] = V; break;
    }
    Sync();
  }

  void Power() override {
    reg[0] = reg[1] = reg[2] = reg[3] = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((BMC12IN1*)fc->fceu->cartiface)->BMC12IN1Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((BMC12IN1*)fc->fceu->cartiface)->Sync();
  }

  BMC12IN1(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{reg, 4, "REGS"}});
  }

};
}

CartInterface *BMC12IN1_Init(FC *fc, CartInfo *info) {
  return new BMC12IN1(fc, info);
}
