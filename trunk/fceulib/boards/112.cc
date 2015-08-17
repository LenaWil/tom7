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
 * NTDEC, ASDER games
 */

#include "mapinc.h"

namespace {
struct Mapper112 : public CartInterface {
  uint8 reg[8] = {};
  uint8 mirror = 0, cmd = 0, bank = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setmirror(mirror ^ 1);
    fc->cart->setprg8(0x8000, reg[0]);
    fc->cart->setprg8(0xA000, reg[1]);
    fc->cart->setchr2(0x0000, (reg[2] >> 1));
    fc->cart->setchr2(0x0800, (reg[3] >> 1));
    fc->cart->setchr1(0x1000, ((bank & 0x10) << 4) | reg[4]);
    fc->cart->setchr1(0x1400, ((bank & 0x20) << 3) | reg[5]);
    fc->cart->setchr1(0x1800, ((bank & 0x40) << 2) | reg[6]);
    fc->cart->setchr1(0x1C00, ((bank & 0x80) << 1) | reg[7]);
  }

  void M112Write(DECLFW_ARGS) {
    switch (A) {
    case 0xe000:
      mirror = V & 1;
      Sync();
      break;
    case 0x8000: cmd = V & 7; break;
    case 0xa000:
      reg[cmd] = V;
      Sync();
      break;
    case 0xc000:
      bank = V;
      Sync();
      break;
    }
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  void Power() override {
    bank = 0;
    fc->cart->setprg16(0xC000, ~0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper112*)fc->fceu->cartiface)->M112Write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4020, 0x5FFF, [](DECLFW_ARGS) {
      ((Mapper112*)fc->fceu->cartiface)->M112Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper112*)fc->fceu->cartiface)->Sync();
  }

  Mapper112(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    WRAM = (uint8 *)FCEU_gmalloc(8192);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, 8192, 1);
    fc->state->AddExState(WRAM, 8192, 0, "WRAM");
    fc->state->AddExVec({
	{&cmd, 1, "CMD0"}, {&mirror, 1, "MIRR"},
        {&bank, 1, "BANK"}, {reg, 8, "REGS"}});
  }
};
}

  
CartInterface *Mapper112_Init(FC *fc, CartInfo *info) {
  return new Mapper112(fc, info);
}
