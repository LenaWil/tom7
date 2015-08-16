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

static constexpr int WRAMSIZE = 16384;

namespace {
struct Mapper103 : public CartInterface {
  uint8 reg0 = 0, reg1 = 0, reg2 = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setchr8(0);
    fc->cart->setprg8(0x8000, 0xc);
    fc->cart->setprg8(0xe000, 0xf);
    if (reg2 & 0x10) {
      fc->cart->setprg8(0x6000, reg0);
      fc->cart->setprg8(0xa000, 0xd);
      fc->cart->setprg8(0xc000, 0xe);
    } else {
      fc->cart->setprg8r(0x10, 0x6000, 0);
      fc->cart->setprg4(0xa000, (0xd << 1));
      fc->cart->setprg2(0xb000, (0xd << 2) + 2);
      fc->cart->setprg2r(0x10, 0xb800, 4);
      fc->cart->setprg2r(0x10, 0xc000, 5);
      fc->cart->setprg2r(0x10, 0xc800, 6);
      fc->cart->setprg2r(0x10, 0xd000, 7);
      fc->cart->setprg2(0xd800, (0xe << 2) + 3);
    }
    fc->cart->setmirror(reg1 ^ 1);
  }

  void M103RamWrite0(DECLFW_ARGS) {
    WRAM[A & 0x1FFF] = V;
  }

  void M103RamWrite1(DECLFW_ARGS) {
    WRAM[0x2000 + ((A - 0xB800) & 0x1FFF)] = V;
  }

  void M103Write0(DECLFW_ARGS) {
    reg0 = V & 0xf;
    Sync();
  }

  void M103Write1(DECLFW_ARGS) {
    reg1 = (V >> 3) & 1;
    Sync();
  }

  void M103Write2(DECLFW_ARGS) {
    reg2 = V;
    Sync();
  }

  void Power() override {
    reg0 = reg1 = 0;
    reg2 = 0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper103*)fc->fceu->cartiface)->
	M103RamWrite0(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0xB800, 0xD7FF, [](DECLFW_ARGS) {
      return ((Mapper103*)fc->fceu->cartiface)->
	M103RamWrite1(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0x8FFF, [](DECLFW_ARGS) {
      return ((Mapper103*)fc->fceu->cartiface)->
	M103Write0(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xE000, 0xEFFF, [](DECLFW_ARGS) {
      return ((Mapper103*)fc->fceu->cartiface)->
	M103Write1(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xF000, 0xFFFF, [](DECLFW_ARGS) {
      return ((Mapper103*)fc->fceu->cartiface)->
	M103Write2(DECLFW_FORWARD);
    });
  }

  void Close() override {
    if (WRAM) free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper103*)fc->fceu->cartiface)->Sync();
  }

  Mapper103(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({
	{&reg0, 1, "REG0"}, {&reg1, 1, "REG1"}, {&reg2, 1, "REG2"}});
  }
};
}

CartInterface *Mapper103_Init(FC *fc, CartInfo *info) {
  return new Mapper103(fc, info);
}
