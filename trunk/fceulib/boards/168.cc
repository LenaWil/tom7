/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static constexpr int CHRRAMSIZE = 8192 * 8;

namespace {
struct Mapper168 : public CartInterface {
  uint8 reg = 0;
  uint8 *CHRRAM = nullptr;

  void Sync() {
    fc->cart->setchr4r(0x10, 0x0000, 0);
    fc->cart->setchr4r(0x10, 0x1000, reg & 0x0f);
    fc->cart->setprg16(0x8000, reg >> 6);
    fc->cart->setprg16(0xc000, ~0);
  }

  void M168Write(DECLFW_ARGS) {
    reg = V;
    Sync();
  }

  void M168Dummy(DECLFW_ARGS) {}

  void Power() override {
    reg = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x4020, 0x7fff, [](DECLFW_ARGS) {
      ((Mapper168*)fc->fceu->cartiface)->M168Dummy(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xB000, 0xB000, [](DECLFW_ARGS) {
      ((Mapper168*)fc->fceu->cartiface)->M168Write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xF000, 0xF000, [](DECLFW_ARGS) {
      ((Mapper168*)fc->fceu->cartiface)->M168Dummy(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xF080, 0xF080, [](DECLFW_ARGS) {
      ((Mapper168*)fc->fceu->cartiface)->M168Dummy(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  void Close() {
    free(CHRRAM);
    CHRRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper168*)fc->fceu->cartiface)->Sync();
  }

  Mapper168(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&reg, 1, "REGS"}});

    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSIZE);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");
  }

};
}

CartInterface *Mapper168_Init(FC *fc, CartInfo *info) {
  return new Mapper168(fc, info);
}
