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
struct UNLBB : public CartInterface {
  uint8 reg = 0, chr = 0;

  void Sync() {
    fc->cart->setprg8(0x6000, reg & 3);
    fc->cart->setprg32(0x8000, ~0);
    fc->cart->setchr8(chr & 3);
  }

  void UNLBBWrite(DECLFW_ARGS) {
    if ((A & 0x9000) == 0x8000) {
      reg = chr = V;
    } else {
      // hacky hacky, ProWres simplified FDS conversion 2-in-1 mapper
      chr = V & 1;
    }
    Sync();
  }

  void Power() override {
    chr = 0;
    reg = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((UNLBB*)fc->fceu->cartiface)->UNLBBWrite(DECLFW_FORWARD);
      });
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLBB *)fc->fceu->cartiface)->Sync();
  }
  
  UNLBB(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}, {&chr, 1, "CHR0"}});
  }
};
}

CartInterface *UNLBB_Init(FC *fc, CartInfo *info) {
  return new UNLBB(fc, info);
}
