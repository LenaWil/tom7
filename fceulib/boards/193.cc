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
struct Mapper193 : public CartInterface {
  uint8 reg[8] = {};
  uint8 mirror = 0, cmd = 0, bank = 0;

  void Sync() {
    fc->cart->setmirror(mirror ^ 1);
    fc->cart->setprg8(0x8000, reg[3]);
    fc->cart->setprg8(0xA000, 0xD);
    fc->cart->setprg8(0xC000, 0xE);
    fc->cart->setprg8(0xE000, 0xF);
    fc->cart->setchr4(0x0000, reg[0] >> 2);
    fc->cart->setchr2(0x1000, reg[1] >> 1);
    fc->cart->setchr2(0x1800, reg[2] >> 1);
  }

  void M193Write(DECLFW_ARGS) {
    reg[A & 3] = V;
    Sync();
  }

  void Power() override {
    bank = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x6000, 0x6003, [](DECLFW_ARGS) {
	((Mapper193*)fc->fceu->cartiface)->M193Write(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, Cart::CartBW);
  }

  void Reset() override {}

  static void StateRestore(FC *fc, int version) {
    ((Mapper193 *)fc->fceu->cartiface)->Sync();
  }

  Mapper193(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&cmd, 1, "CMD0"},
	                 {&mirror, 1, "MIRR"},
			 {&bank, 1, "BANK"},
			 {reg, 8, "REGS"}});
  }
};
}

CartInterface *Mapper193_Init(FC *fc, CartInfo *info) {
  return new Mapper193(fc, info);
}
