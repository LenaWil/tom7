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

namespace {
struct Mapper232 : public CartInterface {
  uint8 bank = 0, preg = 0;

  void Sync() {
    //	uint32 bbank = (bank & 0x18) >> 1;
    // some dumps have bbanks swapped, if swap commands,
    // then all roms can be played, but with some swapped
    // games in menu. if not, some dumps are unplayable
    // make hard dump for both cart types to check
    const uint32 bbank =
	((bank & 0x10) >> 2) |
	(bank & 8);
    fc->cart->setprg16(0x8000, bbank | (preg & 3));
    fc->cart->setprg16(0xC000, bbank | 3);
    fc->cart->setchr8(0);
  }

  void M232WriteBank(DECLFW_ARGS) {
    bank = V;
    Sync();
  }

  void M232WritePreg(DECLFW_ARGS) {
    preg = V;
    Sync();
  }

  void Power() override {
    bank = preg = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
      ((Mapper232*)fc->fceu->cartiface)->M232WriteBank(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xC000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper232*)fc->fceu->cartiface)->M232WritePreg(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper232 *)fc->fceu->cartiface)->Sync();
  }

  Mapper232(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{&bank, 1, "BANK"}, {&preg, 1, "PREG"}});
    fc->fceu->GameStateRestore = StateRestore;
  }

};
}

CartInterface *Mapper232_Init(FC *fc, CartInfo *info) {
  return new Mapper232(fc, info);
}
