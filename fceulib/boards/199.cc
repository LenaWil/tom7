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
 *
 * Dragon Ball Z 2 - Gekishin Freeza! (C)
 * Dragon Ball Z Gaiden - Saiya Jin Zetsumetsu Keikaku (C)
 * San Guo Zhi 2 (C)
 *
 */

#include "mapinc.h"
#include "mmc3.h"

static constexpr uint32 CHRRAMSIZE = 8192;
namespace {
struct Mapper199 : public MMC3 {
  uint8 EXPREGS[8] = {};
  uint8 *CHRRAM = nullptr;

  void PWrap(uint32 A, uint8 V) override {
    fc->cart->setprg8(A, V);
    fc->cart->setprg8(0xC000, EXPREGS[0]);
    fc->cart->setprg8(0xE000, EXPREGS[1]);
  }

  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1r((V < 8) ? 0x10 : 0x00, A, V);
    fc->cart->setchr1r((DRegBuf[0] < 8) ? 0x10 : 0x00, 0x0000, DRegBuf[0]);
    fc->cart->setchr1r((EXPREGS[2] < 8) ? 0x10 : 0x00, 0x0400, EXPREGS[2]);
    fc->cart->setchr1r((DRegBuf[1] < 8) ? 0x10 : 0x00, 0x0800, DRegBuf[1]);
    fc->cart->setchr1r((EXPREGS[3] < 8) ? 0x10 : 0x00, 0x0c00, EXPREGS[3]);
  }

  void MWrap(uint8 V) override {
    //    FCEU_printf("%02x\n",V);
    switch (V & 3) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_0); break;
      case 3: fc->cart->setmirror(MI_1); break;
    }
  }

  void M199Write(DECLFW_ARGS) {
    if ((A == 0x8001) && (MMC3_cmd & 8)) {
      EXPREGS[MMC3_cmd & 3] = V;
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
    } else {
      if (A < 0xC000)
	MMC3_CMDWrite(DECLFW_FORWARD);
      else
	MMC3_IRQWrite(DECLFW_FORWARD);
    }
  }

  void Power() override {
    EXPREGS[0] = ~1;
    EXPREGS[1] = ~0;
    EXPREGS[2] = 1;
    EXPREGS[3] = 3;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper199*)fc->fceu->cartiface)->M199Write(DECLFW_FORWARD);
      });
  }

  void Close() override {
    free(CHRRAM);
    CHRRAM = nullptr;
  }

  Mapper199(FC *fc, CartInfo *info) :
    MMC3(fc, info, 512, 256, 8, info->battery) {
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSIZE);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSIZE, 0, "CHRR");
    fc->state->AddExState(EXPREGS, 4, 0, "EXPR");
  }
};
}

CartInterface *Mapper199_Init(FC *fc, CartInfo *info) {
  return new Mapper199(fc, info);
}
