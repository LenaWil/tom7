/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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

static constexpr int WRAM82SIZE = 8192;

namespace {
struct Mapper82 : public CartInterface {
  uint8 regs[9] = {}, ctrl = 0;
  uint8 *WRAM82 = nullptr;

  void Sync() {
    uint32 swap = ((ctrl & 2) << 11);
    fc->cart->setchr2(0x0000 ^ swap, regs[0] >> 1);
    fc->cart->setchr2(0x0800 ^ swap, regs[1] >> 1);
    fc->cart->setchr1(0x1000 ^ swap, regs[2]);
    fc->cart->setchr1(0x1400 ^ swap, regs[3]);
    fc->cart->setchr1(0x1800 ^ swap, regs[4]);
    fc->cart->setchr1(0x1c00 ^ swap, regs[5]);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0x8000, regs[6]);
    fc->cart->setprg8(0xA000, regs[7]);
    fc->cart->setprg8(0xC000, regs[8]);
    fc->cart->setprg8(0xE000, ~0);
    fc->cart->setmirror(ctrl & 1);
  }

  void M82Write(DECLFW_ARGS) {
    if (A <= 0x7ef5)
      regs[A & 7] = V;
    else
      switch (A) {
	case 0x7ef6: ctrl = V & 3; break;
	case 0x7efa: regs[6] = V >> 2; break;
	case 0x7efb: regs[7] = V >> 2; break;
	case 0x7efc: regs[8] = V >> 2; break;
      }
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xffff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
    // external WRAM82 might end at $73FF
    fc->fceu->SetWriteHandler(0x7ef0, 0x7efc, [](DECLFW_ARGS) {
      ((Mapper82*)fc->fceu->cartiface)->M82Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM82);
    WRAM82 = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper82*)fc->fceu->cartiface)->Sync();
  }

  Mapper82(FC *fc, CartInfo *info) : CartInterface(fc) {
    // Note: This used to set Power a second time, which has got to be
    // a mistake. Changed to Close. -tom7
    // (Later of course these because virtual function overrides)

    WRAM82 = (uint8 *)FCEU_gmalloc(WRAM82SIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM82, WRAM82SIZE, 1);
    fc->state->AddExState(WRAM82, WRAM82SIZE, 0, "WR82");
    if (info->battery) {
      info->SaveGame[0] = WRAM82;
      info->SaveGameLen[0] = WRAM82SIZE;
    }
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{regs, 9, "REGS"}, {&ctrl, 1, "CTRL"}});
  }

};
}

CartInterface *Mapper82_Init(FC *fc, CartInfo *info) {
  return new Mapper82(fc, info);
}
