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
 *
 */

#include "mapinc.h"

namespace {
struct Mapper185Base : public CartInterface {
  uint8 *DummyCHR = nullptr;
  uint8 datareg = 0;

  virtual void WSync() {};

  void MWrite(DECLFW_ARGS) {
    datareg = V;
    WSync();
  }

  void Power() override {
    datareg = 0;
    WSync();
    fc->cart->setprg16(0x8000, 0);
    fc->cart->setprg16(0xC000, ~0);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper185Base*)fc->fceu->cartiface)->MWrite(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  void Close() override {
    free(DummyCHR);
    DummyCHR = nullptr;
  }

  static void MRestore(FC *fc, int version) {
    ((Mapper185Base *)fc->fceu->cartiface)->WSync();
  }

  Mapper185Base(FC *fc, CartInfo *info) : CartInterface(fc) {
    DummyCHR = (uint8 *)FCEU_gmalloc(8192);
    for (int x = 0; x < 8192; x++) DummyCHR[x] = 0xff;
    fc->cart->SetupCartCHRMapping(0x10, DummyCHR, 8192, 0);
    fc->state->AddExVec({{&datareg, 1, "DREG"}});
  }
};

//   on    off
// 1  0x0F, 0xF0 - Bird Week
// 2  0x33, 0x00 - B-Wings
// 3  0x11, 0x00 - Mighty Bomb Jack
// 4  0x22, 0x20 - Sansuu 1 Nen, Sansuu 2 Nen
// 5  0xFF, 0x00 - Sansuu 3 Nen
// 6  0x21, 0x13 - Spy vs Spy
// 7  0x20, 0x21 - Seicross

struct Mapper185 : public Mapper185Base {
  using Mapper185Base::Mapper185Base;
  void WSync() override {
    // little dirty eh? ;_)
    if ((datareg & 3) && (datareg != 0x13))  // 1, 2, 3, 4, 5, 6
      fc->cart->setchr8(0);
    else
      fc->cart->setchr8r(0x10, 0);
  }
};

struct Mapper181 : public Mapper185Base {
  using Mapper185Base::Mapper185Base;
  void WSync() override {
    if (!(datareg & 1))  // 7
      fc->cart->setchr8(0);
    else
      fc->cart->setchr8r(0x10, 0);
  }
};
}

CartInterface *Mapper185_Init(FC *fc, CartInfo *info) {
  return new Mapper185(fc, info);
}

CartInterface *Mapper181_Init(FC *fc, CartInfo *info) {
  return new Mapper181(fc, info);
}
