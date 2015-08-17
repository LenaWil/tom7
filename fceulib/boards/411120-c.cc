/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2008 CaH4e3
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

// actually cart ID is 811120-C, sorry ;) K-3094 - another ID

#include "mapinc.h"
#include "mmc3.h"

namespace {
struct BMC411120C : public MMC3 {
  uint8 EXPREGS[8] = {};
  uint8 reset_flag = 0;

  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1(A, V | ((EXPREGS[0] & 3) << 7));
  }

  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & (8 | reset_flag))
      fc->cart->setprg32(0x8000, ((EXPREGS[0] >> 4) & 3) | (0x0C));
    else
      fc->cart->setprg8(A, (V & 0x0F) | ((EXPREGS[0] & 3) << 4));
  }

  void BMC411120CLoWrite(DECLFW_ARGS) {
    EXPREGS[0] = A;
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Reset() override {
    EXPREGS[0] = 0;
    reset_flag ^= 4;
    MMC3::Reset();
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      ((BMC411120C*)fc->fceu->cartiface)->BMC411120CLoWrite(DECLFW_FORWARD);
    });
  }

  BMC411120C(FC *fc, CartInfo *info) : MMC3(fc, info, 128, 128, 8, 0) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
  }
};
}
  
CartInterface *BMC411120C_Init(FC *fc, CartInfo *info) {
  return new BMC411120C(fc, info);
}
