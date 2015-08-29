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

namespace {
struct Mapper228 : public CartInterface {
  uint8 mram[4] = {}, vreg = 0;
  uint16 areg = 0;

  void Sync() {
    uint32 prgl, prgh, page = (areg >> 7) & 0x3F;
    if ((page & 0x30) == 0x30) page -= 0x10;
    prgl = prgh = (page << 1) + (((areg >> 6) & 1) & ((areg >> 5) & 1));
    prgh += ((areg >> 5) & 1) ^ 1;

    fc->cart->setmirror(((areg >> 13) & 1) ^ 1);
    fc->cart->setprg16(0x8000, prgl);
    fc->cart->setprg16(0xc000, prgh);
    fc->cart->setchr8(((vreg & 0x3) | ((areg & 0xF) << 2)));
  }

  void M228RamWrite(DECLFW_ARGS) {
    mram[A & 3] = V & 0x0F;
  }

  DECLFR_RET M228RamRead(DECLFR_ARGS) {
    return mram[A & 3];
  }

  void M228Write(DECLFW_ARGS) {
    areg = A;
    vreg = V;
    Sync();
  }

  void Reset() override {
    areg = 0x8000;
    vreg = 0;
    Sync();
  }

  void Power() override {
    Reset();
    fc->fceu->SetReadHandler(0x5000, 0x5FFF, [](DECLFR_ARGS) {
      return ((Mapper228*)fc->fceu->cartiface)->M228RamRead(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      ((Mapper228*)fc->fceu->cartiface)->M228RamWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper228*)fc->fceu->cartiface)->M228Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper228 *)fc->fceu->cartiface)->Sync();
  }

  Mapper228(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
      {mram, 4, "MRAM"}, {&areg, 2, "AREG"}, {&vreg, 1, "VREG"}});
  }
};
}

CartInterface *Mapper228_Init(FC *fc, CartInfo *info) {
  return new Mapper228(fc, info);
}
