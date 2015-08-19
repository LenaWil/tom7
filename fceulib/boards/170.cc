/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2011 CaH4e3
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
struct Mapper170 : public CartInterface {
  uint8 reg = 0;

  void Sync() {
    fc->cart->setprg16(0x8000, 0);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(0);
  }

  void M170ProtW(DECLFW_ARGS) {
    reg = V << 1 & 0x80;
  }

  DECLFR_RET M170ProtR(DECLFR_ARGS) {
    return reg | (fc->X->DB & 0x7F);
  }

  void Power() override {
    Sync();
    fc->fceu->SetWriteHandler(0x6502, 0x6502, [](DECLFW_ARGS) {
      ((Mapper170*)fc->fceu->cartiface)->M170ProtW(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x7000, 0x7000, [](DECLFW_ARGS) {
      ((Mapper170*)fc->fceu->cartiface)->M170ProtW(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x7001, 0x7001, [](DECLFR_ARGS) {
      return ((Mapper170*)fc->fceu->cartiface)->M170ProtR(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0x7777, 0x7777, [](DECLFR_ARGS) {
      return ((Mapper170*)fc->fceu->cartiface)->M170ProtR(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper170*)fc->fceu->cartiface)->Sync();
  }

  Mapper170(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}});
  }

};
}

CartInterface *Mapper170_Init(FC *fc, CartInfo *info) {
  return new Mapper170(fc, info);
}
