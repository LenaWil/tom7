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
struct Mapper234 : public CartInterface {
  uint8 bank = 0, preg = 0;

  void Sync() {
    if (bank & 0x40) {
      fc->cart->setprg32(0x8000, (bank & 0xE) | (preg & 1));
      fc->cart->setchr8(((bank & 0xE) << 2) | ((preg >> 4) & 7));
    } else {
      fc->cart->setprg32(0x8000, bank & 0xF);
      fc->cart->setchr8(((bank & 0xF) << 2) | ((preg >> 4) & 3));
    }
    fc->cart->setmirror((bank >> 7) ^ 1);
  }

  DECLFR_RET M234ReadBank(DECLFR_ARGS) {
    uint8 r = Cart::CartBR(DECLFR_FORWARD);
    if (!bank) {
      bank = r;
      Sync();
    }
    return r;
  }

  DECLFR_RET M234ReadPreg(DECLFR_ARGS) {
    uint8 r = Cart::CartBR(DECLFR_FORWARD);
    preg = r;
    Sync();
    return r;
  }

  void Reset() override {
    bank = preg = 0;
    Sync();
  }

  void Power() override {
    Reset();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0xFF80, 0xFF9F, [](DECLFR_ARGS) {
      return ((Mapper234*)fc->fceu->cartiface)->
	M234ReadBank(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0xFFE8, 0xFFF7, [](DECLFR_ARGS) {
      return ((Mapper234*)fc->fceu->cartiface)->
	M234ReadPreg(DECLFR_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper234 *)fc->fceu->cartiface)->Sync();
  }

  Mapper234(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{&bank, 1, "BANK"}, {&preg, 1, "PREG"}});
    fc->fceu->GameStateRestore = StateRestore;
  }
};
}

CartInterface *Mapper234_Init(FC *fc, CartInfo *info) {
  return new Mapper234(fc, info);
}
