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
#include "mmc3.h"

namespace {
struct Mapper189 : public MMC3 {
  uint8 EXPREGS[8] = {};

  void PWrap(uint32 A, uint8 V) override {
    fc->cart->setprg32(0x8000, EXPREGS[0] & 7);
  }

  void M189Write(DECLFW_ARGS) {
    // actually, there are two versions of 189 mapper
    // with hi or lo bits bankswitching.
    EXPREGS[0] = V | (V >> 4);
    FixMMC3PRG(MMC3_cmd);
  }

  void Power() override {
    EXPREGS[0] = EXPREGS[1] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x4120, 0x7FFF, [](DECLFW_ARGS) {
	((Mapper189*)fc->fceu->cartiface)->M189Write(DECLFW_FORWARD);
      });
  }

  Mapper189(FC *fc, CartInfo *info) : MMC3(fc, info, 256, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 2, 0, "EXPR");
  }
};
}

CartInterface *Mapper189_Init(FC *fc, CartInfo *info) {
  return new Mapper189(fc, info);
}
