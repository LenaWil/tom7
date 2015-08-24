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
#include "mmc3.h"

namespace {
struct UNLSHeroes : public MMC3 {
  uint8 EXPREGS[8] = {};
  uint8 tekker = 0;

  void CWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x40) {
      fc->cart->setchr8r(0x10, 0);
    } else {
      if (A < 0x800)
	fc->cart->setchr1(A, V | ((EXPREGS[0] & 8) << 5));
      else if (A < 0x1000)
	fc->cart->setchr1(A, V | ((EXPREGS[0] & 4) << 6));
      else if (A < 0x1800)
	fc->cart->setchr1(A, V | ((EXPREGS[0] & 1) << 8));
      else
	fc->cart->setchr1(A, V | ((EXPREGS[0] & 2) << 7));
    }
  }

  void MSHWrite(DECLFW_ARGS) {
    EXPREGS[0] = V;
    FixMMC3CHR(MMC3_cmd);
  }

  DECLFR_RET MSHRead(DECLFR_ARGS) {
    return tekker;
  }

  void Reset() override {
    MMC3::Reset();
    tekker ^= 0xFF;
  }

  void Power() override {
    tekker = 0x00;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x4100, 0x4100, [](DECLFW_ARGS) {
	((UNLSHeroes*)fc->fceu->cartiface)->MSHWrite(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x4100, 0x4100, [](DECLFR_ARGS) {
	return ((UNLSHeroes*)fc->fceu->cartiface)->MSHRead(DECLFR_FORWARD);
      });
  }

  void Close() override {
    free(CHRRAM);
    CHRRAM = nullptr;
  }

  UNLSHeroes(FC *fc, CartInfo *info) : MMC3(fc, info, 256, 512, 0, 0) {
    // original code didn't set size -tom7
    CHRRAMSize = 8192;
    CHRRAM = (uint8 *)FCEU_gmalloc(8192);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, 8192, 1);
    fc->state->AddExState(EXPREGS, 4, 0, "EXPR");
    fc->state->AddExState(&tekker, 1, 0, "DIPs");
  }
};
}

CartInterface *UNLSHeroes_Init(FC *fc, CartInfo *info) {
  return new UNLSHeroes(fc, info);
}

