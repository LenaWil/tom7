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

// M-022 MMC3 based 830118C T-106 4M + 4M

#include "mapinc.h"
#include "mmc3.h"

namespace {
struct BMC830118C : public MMC3 {
  uint8 EXPREGS[8] = {};

  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1(A, (V & 0x7F) | ((EXPREGS[0] & 0x0c) << 5));
  }

  void PWrap(uint32 A, uint8 V) override {
    if ((EXPREGS[0] & 0x0C) == 0x0C) {
      if (A == 0x8000) {
	fc->cart->setprg8(A, (V & 0x0F) | ((EXPREGS[0] & 0x0c) << 2));
	fc->cart->setprg8(0xC000, (V & 0x0F) | 0x32);
      } else if (A == 0xA000) {
	fc->cart->setprg8(A, (V & 0x0F) | ((EXPREGS[0] & 0x0c) << 2));
	fc->cart->setprg8(0xE000, (V & 0x0F) | 0x32);
      }
    } else {
      fc->cart->setprg8(A, (V & 0x0F) | ((EXPREGS[0] & 0x0c) << 2));
    }
  }

  void BMC830118CLoWrite(DECLFW_ARGS) {
    EXPREGS[0] = V;
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Reset() override {
    EXPREGS[0] = 0;
    MMC3::Reset();
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6800, 0x68FF, [](DECLFW_ARGS) {
      ((BMC830118C*)fc->fceu->cartiface)->BMC830118CLoWrite(DECLFW_FORWARD);
    });
  }

  BMC830118C(FC *fc, CartInfo *info) : MMC3(fc, info, 128, 128, 8, 0) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
  }
};
}

CartInterface *BMC830118C_Init(FC *fc, CartInfo *info) {
  return new BMC830118C(fc, info);
}
