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
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

namespace {
struct UNLKS7031 : public CartInterface {
  uint8 reg[4] = {};

  void Sync() {
    fc->cart->setprg2(0x6000, reg[0]);
    fc->cart->setprg2(0x6800, reg[1]);
    fc->cart->setprg2(0x7000, reg[2]);
    fc->cart->setprg2(0x7800, reg[3]);

    fc->cart->setprg2(0x8000, 15);
    fc->cart->setprg2(0x8800, 14);
    fc->cart->setprg2(0x9000, 13);
    fc->cart->setprg2(0x9800, 12);
    fc->cart->setprg2(0xa000, 11);
    fc->cart->setprg2(0xa800, 10);
    fc->cart->setprg2(0xb000, 9);
    fc->cart->setprg2(0xb800, 8);

    fc->cart->setprg2(0xc000, 7);
    fc->cart->setprg2(0xc800, 6);
    fc->cart->setprg2(0xd000, 5);
    fc->cart->setprg2(0xd800, 4);
    fc->cart->setprg2(0xe000, 3);
    fc->cart->setprg2(0xe800, 2);
    fc->cart->setprg2(0xf000, 1);
    fc->cart->setprg2(0xf800, 0);

    fc->cart->setchr8(0);
  }

  void UNLKS7031Write(DECLFW_ARGS) {
    reg[(A >> 11) & 3] = V;
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
      ((UNLKS7031*)fc->fceu->cartiface)->UNLKS7031Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLKS7031*)fc->fceu->cartiface)->Sync();
  }

  UNLKS7031(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{reg, 4, "REGS"}});
  }

};
}

CartInterface *UNLKS7031_Init(FC *fc, CartInfo *info) {
  return new UNLKS7031(fc, info);
}
