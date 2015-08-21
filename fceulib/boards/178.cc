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

static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper178 : public CartInterface {
  uint8 reg[4] = {};
  uint8 *WRAM = nullptr;

  void Sync() {
    uint8 bank = (reg[2] & 3) << 3;
    fc->cart->setmirror((reg[0] & 1) ^ 1);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setchr8(0);
    if (reg[0] & 2) {
      fc->cart->setprg16(0x8000, (reg[1] & 7) | bank);
      fc->cart->setprg16(0xC000, ((~0) & 7) | bank);
    } else {
      fc->cart->setprg16(0x8000, (reg[1] & 6) | bank);
      fc->cart->setprg16(0xC000, (reg[1] & 6) | bank | 1);
    }
  }

  void M178Write(DECLFW_ARGS) {
    reg[A & 3] = V;
    Sync();
  }

  void Power() override {
    reg[0] = 1;
    reg[1] = 0;
    reg[2] = 0;
    reg[3] = 0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4800, 0x4803, [](DECLFW_ARGS) {
      ((Mapper178*)fc->fceu->cartiface)->M178Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper178*)fc->fceu->cartiface)->Sync();
  }

  Mapper178(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({{reg, 4, "REGS"}});
  }

};
}

CartInterface *Mapper178_Init(FC *fc, CartInfo *info) {
  return new Mapper178(fc, info);
}
