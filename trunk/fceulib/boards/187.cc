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
struct Mapper187 : public MMC3 {
  uint8 EXPREGS[8] = {};

  void CWrap(uint32 A, uint8 V) override {
    if ((A & 0x1000) == ((MMC3_cmd & 0x80) << 5))
      fc->cart->setchr1(A, V | 0x100);
    else
      fc->cart->setchr1(A, V);
  }

  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x80) {
      uint8 bank = EXPREGS[0] & 0x1F;
      if (EXPREGS[0] & 0x20) {
	if (EXPREGS[0] & 0x40) {
	  fc->cart->setprg32(0x8000, bank >> 2);
	} else {
	  // hacky hacky! two
	  // mappers in one! need
	  // real hw carts to test
	  fc->cart->setprg32(0x8000, bank >> 1);
	}
      } else {
	fc->cart->setprg16(0x8000, bank);
	fc->cart->setprg16(0xC000, bank);
      }
    } else {
      fc->cart->setprg8(A, V & 0x3F);
    }
  }

  void M187Write8000(DECLFW_ARGS) {
    EXPREGS[1] = 1;
    MMC3_CMDWrite(DECLFW_FORWARD);
  }

  void M187Write8001(DECLFW_ARGS) {
    if (EXPREGS[1]) MMC3_CMDWrite(DECLFW_FORWARD);
  }

  void M187WriteLo(DECLFW_ARGS) {
    if ((A == 0x5000) || (A == 0x6000)) {
      EXPREGS[0] = V;
      FixMMC3PRG(MMC3_cmd);
    }
  }

  uint8 prot_data[4] = {0x83, 0x83, 0x42, 0x00};
  DECLFR_RET M187Read(DECLFR_ARGS) {
    return prot_data[EXPREGS[1] & 3];
  }

  void Power() override {
    EXPREGS[0] = EXPREGS[1] = 0;
    MMC3::Power();
    fc->fceu->SetReadHandler(0x5000, 0x5FFF, [](DECLFR_ARGS) {
	return ((Mapper187*)fc->fceu->cartiface)->M187Read(DECLFR_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x5000, 0x6FFF, [](DECLFW_ARGS) {
	((Mapper187*)fc->fceu->cartiface)->M187WriteLo(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x8000, 0x8000, [](DECLFW_ARGS) {
	((Mapper187*)fc->fceu->cartiface)->M187Write8000(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x8001, 0x8001, [](DECLFW_ARGS) {
	((Mapper187*)fc->fceu->cartiface)->M187Write8001(DECLFW_FORWARD);
      });
  }

  Mapper187(FC *fc, CartInfo *info) : MMC3(fc, info, 256, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 3, 0, "EXPR");
  }
};
}

CartInterface *Mapper187_Init(FC *fc, CartInfo *info) {
  return new Mapper187(fc, info);
}
