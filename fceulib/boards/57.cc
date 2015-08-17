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
 *
 */

#include "mapinc.h"

namespace {
struct Mapper57 : public CartInterface {
  uint8 prg_reg = 0;
  uint8 chr_reg = 0;
  uint8 hrd_flag = 0;

  void Sync() {
    if (prg_reg & 0x80)
      fc->cart->setprg32(0x8000, prg_reg >> 6);
    else {
      fc->cart->setprg16(0x8000, (prg_reg >> 5) & 3);
      fc->cart->setprg16(0xC000, (prg_reg >> 5) & 3);
    }
    fc->cart->setmirror((prg_reg & 8) >> 3);
    fc->cart->setchr8((chr_reg & 3) | (prg_reg & 7) |
		      ((prg_reg & 0x10) >> 1));
  }

  DECLFR_RET M57Read(DECLFR_ARGS) {
    return hrd_flag;
  }

  void M57Write(DECLFW_ARGS) {
    if ((A & 0x8800) == 0x8800)
      prg_reg = V;
    else
      chr_reg = V;
    Sync();
  }

  void Power() override {
    prg_reg = 0;
    chr_reg = 0;
    hrd_flag = 0;
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper57*)fc->fceu->cartiface)->M57Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x6000, [](DECLFR_ARGS) {
      return ((Mapper57*)fc->fceu->cartiface)->M57Read(DECLFR_FORWARD);
    });
    Sync();
  }

  void Reset() override {
    hrd_flag++;
    hrd_flag &= 3;
    FCEU_printf("Select Register = %02x\n", hrd_flag);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper57*)fc->fceu->cartiface)->Sync();
  }

  Mapper57(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&hrd_flag, 1, "DPSW"}, {&prg_reg, 1, "PRG0"}, {&chr_reg, 1, "CHR0"}});
  }
};
}
  
CartInterface *Mapper57_Init(FC *fc, CartInfo *info) {
  return new Mapper57(fc, info);
}
