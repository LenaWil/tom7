/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
 *  Copyright (C) 2009 qeed
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
 * BMC 42-in-1 "reset switch" + "select switch"
 *
 */

#include "mapinc.h"

namespace {
struct Mapper226Base : public CartInterface {
  const bool isresetbased = false;
  uint8 latch[2] = {}, reset = {};

  void Sync() {
    uint8 bank;
    if (isresetbased) {
      bank = (latch[0] & 0x1f) | (reset << 5) | ((latch[1] & 1) << 6);
    } else {
      bank = (latch[0] & 0x1f) | 
	((latch[0] & 0x80) >> 2) | 
	((latch[1] & 1) << 6);
    }
    if (!(latch[0] & 0x20)) {
      fc->cart->setprg32(0x8000, bank >> 1);
    } else {
      fc->cart->setprg16(0x8000, bank);
      fc->cart->setprg16(0xC000, bank);
    }
    fc->cart->setmirror((latch[0] >> 6) & 1);
    fc->cart->setchr8(0);
  }

  void M226Write(DECLFW_ARGS) {
    latch[A & 1] = V;
    Sync();
  }

  void Power() override {
    latch[0] = latch[1] = reset = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper226Base*)fc->fceu->cartiface)->M226Write(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper226Base *)fc->fceu->cartiface)->Sync();
  }

  Mapper226Base(FC *fc, CartInfo *info, bool resetbased)
    : CartInterface(fc), isresetbased(resetbased) {
    fc->state->AddExVec({{&reset, 1, "RST0"}, {latch, 2, "LATC"}});
    fc->fceu->GameStateRestore = StateRestore;
  }
};

struct Mapper233 : public Mapper226Base {
  using Mapper226Base::Mapper226Base;
  void Reset() override {
    reset ^= 1;
    Sync();
  }
};
}

CartInterface *Mapper226_Init(FC *fc, CartInfo *info) {
  return new Mapper226Base(fc, info, false);
}
CartInterface *Mapper233_Init(FC *fc, CartInfo *info) {
  return new Mapper233(fc, info, true);
}
