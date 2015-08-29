/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
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
struct DreamTech01 : public CartInterface {
  uint8 latch = 0;

  void Sync() {
    fc->cart->setprg16(0x8000, latch);
    fc->cart->setprg16(0xC000, 8);
  }

  void DREAMWrite(DECLFW_ARGS) {
    latch = V & 7;
    Sync();
  }

  void Power() override {
    latch = 0;
    Sync();
    fc->cart->setchr8(0);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x5020, 0x5020, [](DECLFW_ARGS) {
      ((DreamTech01*)fc->fceu->cartiface)->DREAMWrite(DECLFW_FORWARD);
    });
  }

  static void Restore(FC *fc, int version) {
    ((DreamTech01 *)fc->fceu->cartiface)->Sync();
  }

  DreamTech01(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = Restore;
    fc->state->AddExState(&latch, 1, 0, "LATC");
  }
};
}

CartInterface *DreamTech01_Init(FC *fc, CartInfo *info) {
  return new DreamTech01(fc, info);
}
