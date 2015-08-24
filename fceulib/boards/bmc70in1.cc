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

namespace {
struct BMC70 : public CartInterface {
  const bool is_large_banks = false;
  uint8 hw_switch = 0;
  uint8 large_bank = 0;
  uint8 prg_bank = 0;
  uint8 chr_bank = 0;
  uint8 bank_mode = 0;
  uint8 mirroring = 0;

  void Sync() {
    switch (bank_mode) {
      case 0x00:
      case 0x10:
	fc->cart->setprg16(0x8000, large_bank | prg_bank);
	fc->cart->setprg16(0xC000, large_bank | 7);
	break;
      case 0x20:
	fc->cart->setprg32(0x8000, (large_bank | prg_bank) >> 1);
	break;
      case 0x30:
	fc->cart->setprg16(0x8000, large_bank | prg_bank);
	fc->cart->setprg16(0xC000, large_bank | prg_bank);
	break;
    }
    fc->cart->setmirror(mirroring);
    if (!is_large_banks) fc->cart->setchr8(chr_bank);
  }

  DECLFR_RET BMC70in1Read(DECLFR_ARGS) {
    if (bank_mode == 0x10)
      //    if(is_large_banks)
      return Cart::CartBR(fc, (A & 0xFFF0) | hw_switch);
    //    else
    //      return CartBR((A&0xFFF0)|hw_switch);
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }

  void BMC70in1Write(DECLFW_ARGS) {
    if (A & 0x4000) {
      bank_mode = A & 0x30;
      prg_bank = A & 7;
    } else {
      mirroring = ((A & 0x20) >> 5) ^ 1;
      if (is_large_banks)
	large_bank = (A & 3) << 3;
      else
	chr_bank = A & 7;
    }
    Sync();
  }

  void Reset() override {
    bank_mode = 0;
    large_bank = 0;
    Sync();
    hw_switch++;
    hw_switch &= 0xf;
  }

  void Power() override {
    fc->cart->setchr8(0);
    bank_mode = 0;
    large_bank = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, [](DECLFR_ARGS) {
	return ((BMC70*)fc->fceu->cartiface)->
	  BMC70in1Read(DECLFR_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
	((BMC70*)fc->fceu->cartiface)->
	  BMC70in1Write(DECLFW_FORWARD);
      });
  }

  static void StateRestore(FC *fc, int version) {
    ((BMC70 *)fc->fceu->cartiface)->Sync();
  }

  BMC70(FC *fc, CartInfo *info, bool ilb, uint8 hw) :
    CartInterface(fc), is_large_banks(ilb), hw_switch(hw) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&large_bank, 1, "LB00"},
			 {&hw_switch, 1, "DPSW"},
			 {&prg_bank, 1, "PRG0"},
			 {&chr_bank, 1, "CHR0"},
			 {&bank_mode, 1, "BM00"},
			 {&mirroring, 1, "MIRR"}});
  }
};
}

CartInterface *BMC70in1_Init(FC *fc, CartInfo *info) {
  return new BMC70(fc, info, false, 0xd);
}

CartInterface *BMC70in1B_Init(FC *fc, CartInfo *info) {
  return new BMC70(fc, info, true, 0x6);
}
