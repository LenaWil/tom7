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
struct MapperGS2013 : public CartInterface {
  uint8 reg = 0, mirr = 0;

  void Sync() {
    fc->cart->setprg8r(0, 0x6000, ~0);
    fc->cart->setprg32r((reg & 8) >> 3, 0x8000, reg);
    fc->cart->setchr8(0);
  }

  void BMCGS2013Write(DECLFW_ARGS) {
    reg = V;
    Sync();
  }

  void Power() override {
    reg = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      return ((MapperGS2013*)fc->fceu->cartiface)->
	BMCGS2013Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    reg = ~0;
  }

  static void StateRestore(FC *fc, int version) {
    ((MapperGS2013*)fc->fceu->cartiface)->Sync();
  }

  MapperGS2013(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}, {&mirr, 1, "MIRR"}});
  }
};
}

CartInterface *BMCGS2013_Init(FC *fc, CartInfo *info) {
  return new MapperGS2013(fc, info);
}
