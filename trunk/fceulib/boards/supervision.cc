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
struct Supervision16 : public CartInterface {

  uint8 cmd0 = 0, cmd1 = 0;

  void DoSuper() {
    fc->cart->setprg8r((cmd0 & 0xC) >> 2, 0x6000,
		       ((cmd0 & 0x3) << 4) | 0xF);
    if (cmd0 & 0x10) {
      fc->cart->setprg16r((cmd0 & 0xC) >> 2, 0x8000,
			  ((cmd0 & 0x3) << 3) | (cmd1 & 7));
      fc->cart->setprg16r((cmd0 & 0xC) >> 2, 0xc000,
			  ((cmd0 & 0x3) << 3) | 7);
    } else {
      fc->cart->setprg32r(4, 0x8000, 0);
    }
    fc->cart->setmirror(((cmd0 & 0x20) >> 5) ^ 1);
  }

  void SuperWrite(DECLFW_ARGS) {
    if (!(cmd0 & 0x10)) {
      cmd0 = V;
      DoSuper();
    }
  }

  void SuperHi(DECLFW_ARGS) {
    cmd1 = V;
    DoSuper();
  }

  // was "SuperReset", but went in Power slot -tom7
  void Power() override {
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      ((Supervision16*)fc->fceu->cartiface)->SuperWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Supervision16*)fc->fceu->cartiface)->SuperHi(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    cmd0 = cmd1 = 0;
    fc->cart->setprg32r(4, 0x8000, 0);
    fc->cart->setchr8(0);
  }

  static void SuperRestore(FC *fc, int version) {
    ((Supervision16 *)fc->fceu->cartiface)->DoSuper();
  }

  Supervision16(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExState(&cmd0, 1, 0, "L100");
    fc->state->AddExState(&cmd1, 1, 0, "L200");
    fc->fceu->GameStateRestore = SuperRestore;
  }
};
}

CartInterface *Supervision16_Init(FC *fc, CartInfo *info) {
  return new Supervision16(fc, info);
}
