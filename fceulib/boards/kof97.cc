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
struct KOF97 : public MMC3 {

  void UNLKOF97CMDWrite(DECLFW_ARGS) {
    // 76143502
    V = (V & 0xD8) | ((V & 0x20) >> 4) | ((V & 4) << 3) |
      ((V & 2) >> 1) | ((V & 1) << 2);
    if (A == 0x9000) A = 0x8001;
    MMC3_CMDWrite(DECLFW_FORWARD);
  }

  void UNLKOF97IRQWrite(DECLFW_ARGS) {
    V = (V & 0xD8) | ((V & 0x20) >> 4) | ((V & 4) << 3) |
      ((V & 2) >> 1) | ((V & 1) << 2);
    if (A == 0xD000)
      A = 0xC001;
    else if (A == 0xF000)
      A = 0xE001;
    MMC3_IRQWrite(DECLFW_FORWARD);
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x8000, 0xA000, [](DECLFW_ARGS) {
      ((KOF97*)fc->fceu->cartiface)->UNLKOF97CMDWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xC000, 0xF000, [](DECLFW_ARGS) {
      ((KOF97*)fc->fceu->cartiface)->UNLKOF97IRQWrite(DECLFW_FORWARD);
    });
  }

  KOF97(FC *fc, CartInfo *info) : MMC3(fc, info, 128, 256, 0, 0) {
  }
};
}

CartInterface *UNLKOF97_Init(FC *fc, CartInfo *info) {
  return new KOF97(fc, info);
}
