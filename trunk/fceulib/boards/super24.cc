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

static constexpr int masko8[8] = {63, 31, 15, 1, 3, 0, 0, 0};

namespace {
struct Super24 : public MMC3 {
  uint8 EXPREGS[8] = {};
  
  void PWrap(uint32 A, uint8 V) override {
    uint32 NV = V & masko8[EXPREGS[0] & 7];
    NV |= (EXPREGS[1] << 1);
    fc->cart->setprg8r((NV >> 6) & 0xF, A, NV);
  }

  void CWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x20) {
      fc->cart->setchr1r(0x10, A, V);
    } else {
      uint32 NV = V | (EXPREGS[2] << 3);
      fc->cart->setchr1r((NV >> 9) & 0xF, A, NV);
    }
  }

  void Super24Write(DECLFW_ARGS) {
    switch (A) {
      case 0x5FF0:
	EXPREGS[0] = V;
	FixMMC3PRG(MMC3_cmd);
	FixMMC3CHR(MMC3_cmd);
	break;
      case 0x5FF1:
	EXPREGS[1] = V;
	FixMMC3PRG(MMC3_cmd);
	break;
      case 0x5FF2:
	EXPREGS[2] = V;
	FixMMC3CHR(MMC3_cmd);
	break;
    }
  }

  void Power() override {
    EXPREGS[0] = 0x24;
    EXPREGS[1] = 159;
    EXPREGS[2] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x5000, 0x7FFF, [](DECLFW_ARGS) {
      ((Super24*)fc->fceu->cartiface)->Super24Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  void Reset() override {
    EXPREGS[0] = 0x24;
    EXPREGS[1] = 159;
    EXPREGS[2] = 0;
    MMC3::Reset();
  }

  void Close() override {
    free(CHRRAM);
    CHRRAM = nullptr;
  }

  Super24(FC *fc, CartInfo *info) : MMC3(fc, info, 128, 256, 0, 0) {
    CHRRAM = (uint8 *)FCEU_gmalloc(8192);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, 8192, 1);
    fc->state->AddExState(CHRRAM, 8192, 0, "CHRR");
    fc->state->AddExState(EXPREGS, 3, 0, "BIG2");
  }
};
}

CartInterface *Super24_Init(FC *fc, CartInfo *info) {
  return new Super24(fc, info);
}
