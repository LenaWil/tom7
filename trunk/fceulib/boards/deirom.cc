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
struct DEIROM : public CartInterface {
  uint8 cmd = 0;
  uint8 DRegs[8] = {};

  void Sync() {
    fc->cart->setchr2(0x0000, DRegs[0]);
    fc->cart->setchr2(0x0800, DRegs[1]);
    for (int x = 0; x < 4; x++)
      fc->cart->setchr1(0x1000 + (x << 10), DRegs[2 + x]);
    fc->cart->setprg8(0x8000, DRegs[6]);
    fc->cart->setprg8(0xa000, DRegs[7]);
  }

  void DEIWrite(DECLFW_ARGS) {
    switch (A & 0x8001) {
      case 0x8000: cmd = V & 0x07; break;
      case 0x8001:
	if (cmd <= 0x05)
	  V &= 0x3F;
	else
	  V &= 0x0F;
	if (cmd <= 0x01) V >>= 1;
	DRegs[cmd & 0x07] = V;
	Sync();
	break;
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((DEIROM *)fc->fceu->cartiface)->Sync();
  }

  void Power() override {
    fc->cart->setprg8(0xc000, 0xE);
    fc->cart->setprg8(0xe000, 0xF);
    cmd = 0;
    memset(DRegs, 0, 8);
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((DEIROM*)fc->fceu->cartiface)->DEIWrite(DECLFW_FORWARD);
    });
  }

  DEIROM(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&cmd, 1, "CMD0"}, {DRegs, 8, "DREG"}});
  }
};
}

CartInterface *DEIROM_Init(FC *fc, CartInfo *info) {
  return new DEIROM(fc, info);
}
