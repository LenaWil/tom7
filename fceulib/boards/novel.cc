/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
struct Novel : public CartInterface {

  uint8 latch = 0;

  void DoNovel() {
    fc->cart->setprg32(0x8000, latch & 3);
    fc->cart->setchr8(latch & 7);
  }

  void NovelWrite(DECLFW_ARGS) {
    latch = A & 0xFF;
    DoNovel();
  }

  // Used to be NovelReset, but assigned to Power.
  void Power() override {
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Novel*)fc->fceu->cartiface)->NovelWrite(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(0);
  }

  static void NovelRestore(FC *fc, int version) {
    ((Novel*)fc->fceu->cartiface)->DoNovel();
  }

  Novel(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExState(&latch, 1, 0, "L100");
    fc->fceu->GameStateRestore = NovelRestore;
  }
};
}

CartInterface *Novel_Init(FC *fc, CartInfo *info) {
  return new Novel(fc, info);
}
