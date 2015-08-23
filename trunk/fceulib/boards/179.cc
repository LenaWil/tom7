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
struct Mapper179 : public CartInterface {
  uint8 reg[2] = {};
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, reg[1] >> 1);
    fc->cart->setmirror((reg[0] & 1) ^ 1);
  }

  void M179Write(DECLFW_ARGS) {
    if (A == 0xa000) reg[0] = V;
    Sync();
  }

  void M179WriteLo(DECLFW_ARGS) {
    if (A == 0x5ff1) reg[1] = V;
    Sync();
  }

  void Power() override {
    reg[0] = reg[1] = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x4020, 0x5fff, [](DECLFW_ARGS) {
	((Mapper179*)fc->fceu->cartiface)->M179WriteLo(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper179*)fc->fceu->cartiface)->M179Write(DECLFW_FORWARD);
      });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper179*)fc->fceu->cartiface)->Sync();
  }

  Mapper179(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }

    fc->state->AddExVec({{reg, 2, "REGS"}});
  }
};
}

CartInterface *Mapper179_Init(FC *fc, CartInfo *info) {
  return new Mapper179(fc, info);
}
