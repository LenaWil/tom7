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

static constexpr uint8 m114_perm[8] = {0, 3, 1, 5, 6, 7, 2, 4};

namespace {
struct H2288 : public MMC3 {
  uint8 EXPREGS[8] = {};

  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x40) {
      uint8 bank =
	  (EXPREGS[0] & 5) | ((EXPREGS[0] & 8) >> 2) |
	((EXPREGS[0] & 0x20) >> 2);
      if (EXPREGS[0] & 2) {
	fc->cart->setprg32(0x8000, bank >> 1);
      } else {
	fc->cart->setprg16(0x8000, bank);
	fc->cart->setprg16(0xC000, bank);
      }
    } else {
      fc->cart->setprg8(A, V & 0x3F);
    }
  }

  void H2288WriteHi(DECLFW_ARGS) {
    switch (A & 0x8001) {
      case 0x8000:
	MMC3_CMDWrite(fc, 0x8000, (V & 0xC0) | (m114_perm[V & 7]));
	break;
      case 0x8001:
	MMC3_CMDWrite(fc, 0x8001, V);
	break;
    }
  }

  void H2288WriteLo(DECLFW_ARGS) {
    if (A & 0x800) {
      if (A & 1)
	EXPREGS[1] = V;
      else
	EXPREGS[0] = V;
      FixMMC3PRG(MMC3_cmd);
    }
  }

  void Power() override {
    EXPREGS[0] = EXPREGS[1] = 0;
    MMC3::Power();
    //  fc->fceu->SetReadHandler(0x5000,0x5FFF,H2288Read);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      return ((H2288*)fc->fceu->cartiface)->
	H2288WriteLo(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0x9FFF, [](DECLFW_ARGS) {
      return ((H2288*)fc->fceu->cartiface)->
	H2288WriteHi(DECLFW_FORWARD);
    });
  }

  H2288(FC *fc, CartInfo *info)
    : MMC3(fc, info, 256, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 2, 0, "EXPR");
  }
};
}
  
CartInterface *UNLH2288_Init(FC *fc, CartInfo *info) {
  return new H2288(fc, info);
}
