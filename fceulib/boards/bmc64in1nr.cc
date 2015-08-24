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
 *
 * BMC 42-in-1 "reset switch" type
 */

#include "mapinc.h"

namespace {
struct BMC64in1nr : public CartInterface {
  uint8 regs[4] = {};

  void Sync() {
    if (regs[0] & 0x80) {
      if (regs[1] & 0x80) {
	fc->cart->setprg32(0x8000, regs[1] & 0x1F);
      } else {
	int bank = ((regs[1] & 0x1f) << 1) | ((regs[1] >> 6) & 1);
	fc->cart->setprg16(0x8000, bank);
	fc->cart->setprg16(0xC000, bank);
      }
    } else {
      int bank = ((regs[1] & 0x1f) << 1) | ((regs[1] >> 6) & 1);
      fc->cart->setprg16(0xC000, bank);
    }
    if (regs[0] & 0x20)
      fc->cart->setmirror(MI_H);
    else
      fc->cart->setmirror(MI_V);
    fc->cart->setchr8((regs[2] << 2) | ((regs[0] >> 1) & 3));
  }

  void BMC64in1nrWriteLo(DECLFW_ARGS) {
    regs[A & 3] = V;
    Sync();
  }

  void BMC64in1nrWriteHi(DECLFW_ARGS) {
    regs[3] = V;
    Sync();
  }

  void Power() override {
    regs[0] = 0x80;
    regs[1] = 0x43;
    regs[2] = regs[3] = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x5000, 0x5003, [](DECLFW_ARGS) {
	((BMC64in1nr*)fc->fceu->cartiface)->BMC64in1nrWriteLo(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((BMC64in1nr*)fc->fceu->cartiface)->BMC64in1nrWriteHi(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((BMC64in1nr *)fc->fceu->cartiface)->Sync();
  }

  BMC64in1nr(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{regs, 4, "REGS"}});
    fc->fceu->GameStateRestore = StateRestore;
  }
};
}

CartInterface *BMC64in1nr_Init(FC *fc, CartInfo *info) {
  return new BMC64in1nr(fc, info);
}
