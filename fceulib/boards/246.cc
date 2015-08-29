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

static constexpr uint32 WRAMSIZE = 2048;

namespace {
struct Mapper246 : public CartInterface {
  uint8 regs[8] = {};
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setprg2r(0x10, 0x6800, 0);
    fc->cart->setprg8(0x8000, regs[0]);
    fc->cart->setprg8(0xA000, regs[1]);
    fc->cart->setprg8(0xC000, regs[2]);
    fc->cart->setprg8(0xE000, regs[3]);
    fc->cart->setchr2(0x0000, regs[4]);
    fc->cart->setchr2(0x0800, regs[5]);
    fc->cart->setchr2(0x1000, regs[6]);
    fc->cart->setchr2(0x1800, regs[7]);
  }

  void M246Write(DECLFW_ARGS) {
    regs[A & 7] = V;
    Sync();
  }

  void Power() override {
    regs[0] = regs[1] = regs[2] = regs[3] = ~0;
    Sync();
    fc->fceu->SetWriteHandler(0x6000, 0x67FF, [](DECLFW_ARGS) {
      ((Mapper246*)fc->fceu->cartiface)->M246Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6800, 0x6FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6800, 0x6FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper246 *)fc->fceu->cartiface)->Sync();
  }

  Mapper246(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }

    fc->state->AddExVec({{regs, 8, "REGS"}});
  }
};
}

CartInterface *Mapper246_Init(FC *fc, CartInfo *info) {
  return new Mapper246(fc, info);
}
