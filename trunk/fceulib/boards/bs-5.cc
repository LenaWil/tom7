/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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
struct BMCBS5 : public CartInterface {
  uint8 reg_prg[4] = {};
  uint8 reg_chr[4] = {};
  uint8 dip_switch = 0;

  void Sync() {
    fc->cart->setprg8(0x8000, reg_prg[0]);
    fc->cart->setprg8(0xa000, reg_prg[1]);
    fc->cart->setprg8(0xc000, reg_prg[2]);
    fc->cart->setprg8(0xe000, reg_prg[3]);
    fc->cart->setchr2(0x0000, reg_chr[0]);
    fc->cart->setchr2(0x0800, reg_chr[1]);
    fc->cart->setchr2(0x1000, reg_chr[2]);
    fc->cart->setchr2(0x1800, reg_chr[3]);
    fc->cart->setmirror(MI_V);
  }

  void MBS5Write(DECLFW_ARGS) {
    int bank_sel = (A & 0xC00) >> 10;
    switch (A & 0xF000) {
      case 0x8000: reg_chr[bank_sel] = A & 0x1F; break;
      case 0xA000:
	if (A & (1 << (dip_switch + 4))) reg_prg[bank_sel] = A & 0x0F;
	break;
    }
    Sync();
  }

  void Reset() override {
    dip_switch++;
    dip_switch &= 3;
    reg_prg[0] = reg_prg[1] = reg_prg[2] = reg_prg[3] = ~0;
    Sync();
  }

  void Power() override {
    dip_switch = 0;
    reg_prg[0] = reg_prg[1] = reg_prg[2] = reg_prg[3] = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((BMCBS5*)fc->fceu->cartiface)->MBS5Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((BMCBS5 *)fc->fceu->cartiface)->Sync();
  }

  BMCBS5(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{reg_prg, 4, "PREG"}, {reg_chr, 4, "CREG"}});
  }
};
}

CartInterface *BMCBS5_Init(FC *fc, CartInfo *info) {
  return new BMCBS5(fc, info);
}
