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
 * 22 + Contra Reset based custom mapper...
 *
 */

#include "mapinc.h"

namespace {
struct Mapper230 : public CartInterface {
  uint8 latch = 0, reset = 0;

  void Sync() {
    if (reset) {
      fc->cart->setprg16(0x8000, latch & 7);
      fc->cart->setprg16(0xC000, 7);
      fc->cart->setmirror(MI_V);
    } else {
      uint32 bank = (latch & 0x1F) + 8;
      if (latch & 0x20) {
	fc->cart->setprg16(0x8000, bank);
	fc->cart->setprg16(0xC000, bank);
      } else {
	fc->cart->setprg32(0x8000, bank >> 1);
      }
      fc->cart->setmirror((latch >> 6) & 1);
    }
    fc->cart->setchr8(0);
  }

  void M230Write(DECLFW_ARGS) {
    latch = V;
    Sync();
  }

  void Reset() override {
    reset ^= 1;
    Sync();
  }

  void Power() override {
    latch = reset = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper230*)fc->fceu->cartiface)->M230Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper230 *)fc->fceu->cartiface)->Sync();
  }

  Mapper230(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{&reset, 1, "RST0"}, {&latch, 1, "LATC"}});
    fc->fceu->GameStateRestore = StateRestore;
  }
};
}

CartInterface *Mapper230_Init(FC *fc, CartInfo *info) {
  return new Mapper230(fc, info);
}
