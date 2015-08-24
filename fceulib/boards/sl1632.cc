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
struct UNLSL1632 : public MMC3 {
  // brk is a system call in *nix, and is an illegal variable name - soules
  // tom7 removed 'swap' which had the same problem but was dead
  uint8 chrcmd[8] = {}, prg0 = 0, prg1 = 0, bbrk = 0, mirr = 0;

  void Sync() {
    fc->cart->setprg8(0x8000, prg0);
    fc->cart->setprg8(0xA000, prg1);
    fc->cart->setprg8(0xC000, ~1);
    fc->cart->setprg8(0xE000, ~0);
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chrcmd[i]);
    fc->cart->setmirror(mirr ^ 1);
  }

  void CWrap(uint32 A, uint8 V) override {
    int cbase = (MMC3_cmd & 0x80) << 5;
    int page0 = (bbrk & 0x08) << 5;
    int page1 = (bbrk & 0x20) << 3;
    int page2 = (bbrk & 0x80) << 1;
    fc->cart->setchr1(cbase ^ 0x0000, page0 | (DRegBuf[0] & (~1)));
    fc->cart->setchr1(cbase ^ 0x0400, page0 | DRegBuf[0] | 1);
    fc->cart->setchr1(cbase ^ 0x0800, page0 | (DRegBuf[1] & (~1)));
    fc->cart->setchr1(cbase ^ 0x0C00, page0 | DRegBuf[1] | 1);
    fc->cart->setchr1(cbase ^ 0x1000, page1 | DRegBuf[2]);
    fc->cart->setchr1(cbase ^ 0x1400, page1 | DRegBuf[3]);
    fc->cart->setchr1(cbase ^ 0x1800, page2 | DRegBuf[4]);
    fc->cart->setchr1(cbase ^ 0x1c00, page2 | DRegBuf[5]);
  }

  void UNLSL1632CMDWrite(DECLFW_ARGS) {
    if (A == 0xA131) {
      bbrk = V;
    }
    if (bbrk & 2) {
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
      if (A < 0xC000)
	MMC3_CMDWrite(DECLFW_FORWARD);
      else
	MMC3_IRQWrite(DECLFW_FORWARD);
    } else {
      if ((A >= 0xB000) && (A <= 0xE003)) {
	int ind = ((((A & 2) | (A >> 10)) >> 1) + 2) & 7;
	int sar = ((A & 1) << 2);
	chrcmd[ind] = (chrcmd[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
      } else
	switch (A & 0xF003) {
	  case 0x8000: prg0 = V; break;
	  case 0xA000: prg1 = V; break;
	  case 0x9000: mirr = V & 1; break;
	}
      Sync();
    }
  }

  void SrSync() {
    if (bbrk & 2) {
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
    } else {
      Sync();
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLSL1632 *)fc->fceu->cartiface)->SrSync();
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x4100, 0xFFFF, [](DECLFW_ARGS) {
	((UNLSL1632*)fc->fceu->cartiface)->UNLSL1632CMDWrite(DECLFW_FORWARD);
      });
  }

  UNLSL1632(FC *fc, CartInfo *info) : MMC3(fc, info, 256, 512, 0, 0) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{chrcmd, 8, "CHRC"},
	{&prg0, 1, "PRG0"},
	{&prg1, 1, "PRG1"},
	{&bbrk, 1, "BRK0"},
	{&mirr, 1, "MIRR"}
      });
  }
};
}

CartInterface *UNLSL1632_Init(FC *fc, CartInfo *info) {
  return new UNLSL1632(fc, info);
}
