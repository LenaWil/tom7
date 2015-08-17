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

static constexpr uint8 lut[4] = {0x00, 0x02, 0x02, 0x03};

namespace {
struct UNL6035052 : public MMC3 {
  uint8 EXPREGS[8] = {};

  void UNL6035052ProtWrite(DECLFW_ARGS) {
    EXPREGS[0] = lut[V & 3];
  }

  DECLFR_RET UNL6035052ProtRead(DECLFR_ARGS) {
    return EXPREGS[0];
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x4020, 0x7FFF, [](DECLFW_ARGS) {
      ((UNL6035052*)fc->fceu->cartiface)->UNL6035052ProtWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x4020, 0x7FFF, [](DECLFR_ARGS) {
      return ((UNL6035052*)fc->fceu->cartiface)->
	UNL6035052ProtRead(DECLFR_FORWARD);
    });
  }

  UNL6035052(FC *fc, CartInfo *info) : MMC3(fc, info, 128, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 6, 0, "EXPR");
  }
};
}

CartInterface *UNL6035052_Init(FC *fc, CartInfo *info) {
  return new UNL6035052(fc, info);
}
