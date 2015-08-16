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

static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper32 : public CartInterface {
  uint8 preg[2] = {}, creg[8] = {}, mirr = 0;

  uint8 *WRAM = nullptr;

  void Sync() {
    uint16 swap = ((mirr & 2) << 13);
    fc->cart->setmirror((mirr & 1) ^ 1);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0x8000 ^ swap, preg[0]);
    fc->cart->setprg8(0xA000, preg[1]);
    fc->cart->setprg8(0xC000 ^ swap, ~1);
    fc->cart->setprg8(0xE000, ~0);
    for (uint8 i = 0; i < 8; i++) fc->cart->setchr1(i << 10, creg[i]);
  }

  void M32Write0(DECLFW_ARGS) {
    preg[0] = V;
    Sync();
  }

  void M32Write1(DECLFW_ARGS) {
    mirr = V;
    Sync();
  }

  void M32Write2(DECLFW_ARGS) {
    preg[1] = V;
    Sync();
  }

  void M32Write3(DECLFW_ARGS) {
    creg[A & 7] = V;
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0x8FFF, [](DECLFW_ARGS) {
      return ((Mapper32*)fc->fceu->cartiface)->
	M32Write0(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x9000, 0x9FFF, [](DECLFW_ARGS) {
      return ((Mapper32*)fc->fceu->cartiface)->
	M32Write1(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xA000, 0xAFFF, [](DECLFW_ARGS) {
      return ((Mapper32*)fc->fceu->cartiface)->
	M32Write2(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xB000, 0xBFFF, [](DECLFW_ARGS) {
      return ((Mapper32*)fc->fceu->cartiface)->
	M32Write3(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper32*)fc->fceu->cartiface)->Sync();
  }

  Mapper32(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({
	{preg, 4, "PREG"}, {creg, 8, "CREG"}, {&mirr, 1, "MIRR"}});
  }
};
}

CartInterface *Mapper32_Init(FC *fc, CartInfo *info) {
  return new Mapper32(fc, info);
}
