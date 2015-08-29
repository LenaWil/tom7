/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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
struct BMCT262 : public CartInterface {
  uint16 addrreg = 0;
  uint8 datareg = 0;
  uint8 busy = 0;

  void Sync() {
    uint16 base = ((addrreg & 0x60) >> 2) | ((addrreg & 0x100) >> 3);
    fc->cart->setprg16(0x8000, (datareg & 7) | base);
    fc->cart->setprg16(0xC000, 7 | base);
    fc->cart->setmirror(((addrreg & 2) >> 1) ^ 1);
  }

  void BMCT262Write(DECLFW_ARGS) {
    if (busy || (A == 0x8000))
      datareg = V;
    else {
      addrreg = A;
      busy = 1;
    }
    Sync();
  }

  void Power() override {
    fc->cart->setchr8(0);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((BMCT262*)fc->fceu->cartiface)->BMCT262Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    busy = 0;
    addrreg = 0;
    datareg = 0xff;
    Sync();
  }

  void Reset() override {
    busy = 0;
    addrreg = 0;
    datareg = 0;
    Sync();
  }

  static void BMCT262Restore(FC *fc, int version) {
    ((BMCT262 *)fc->fceu->cartiface)->Sync();
  }
  
  BMCT262(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = BMCT262Restore;
    fc->state->AddExVec({
	{&addrreg, 2, "AREG"}, {&datareg, 1, "DREG"}, {&busy, 1, "BUSY"}});
  }
};
}

CartInterface *BMCT262_Init(FC *fc, CartInfo *info) {
  return new BMCT262(fc, info);
}
