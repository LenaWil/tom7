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

#include "ines.h"

namespace {
struct Mapper188 : public CartInterface {
  uint8 latch = 0;

  void Sync() {
    if (latch) {
      if (latch & 0x10)
	fc->cart->setprg16(0x8000, (latch & 7));
      else
	fc->cart->setprg16(0x8000, (latch & 7) | 8);
    } else {
      fc->cart->setprg16(0x8000, 7 + (fc->ines->ROM_size >> 4));
    }
  }

  void M188Write(DECLFW_ARGS) {
    latch = V;
    Sync();
  }

  void Power() override {
    latch = 0;
    Sync();
    fc->cart->setchr8(0);
    fc->cart->setprg16(0xc000, 0x7);
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, [](DECLFR_ARGS) -> DECLFR_RET {
      return 3;
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper188*)fc->fceu->cartiface)->M188Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper188*)fc->fceu->cartiface)->Sync();
  }

  Mapper188(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExState(&latch, 1, 0, "LATC");
  }
};
}

CartInterface *Mapper188_Init(FC *fc, CartInfo *info) {
  return new Mapper188(fc, info);
}
