/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
#include "../ines.h"

namespace {
struct Mapper95 : public CartInterface {

  uint8 lastA = 0;
  uint8 DRegs[8] = {};
  uint8 cmd = 0;
  uint8 MirCache[8] = {};

  void toot() {
    MirCache[0] = MirCache[1] = (DRegs[0] >> 4) & 1;
    MirCache[2] = MirCache[3] = (DRegs[1] >> 4) & 1;

    for (int x = 0; x < 4; x++) MirCache[4 + x] = (DRegs[2 + x] >> 5) & 1;
    fc->ines->onemir(MirCache[lastA]);
  }

  void Sync() {
    fc->cart->setchr2(0x0000, DRegs[0] & 0x1F);
    fc->cart->setchr2(0x0800, DRegs[1] & 0x1F);
    fc->cart->setchr1(0x1000, DRegs[2] & 0x1F);
    fc->cart->setchr1(0x1400, DRegs[3] & 0x1F);
    fc->cart->setchr1(0x1800, DRegs[4] & 0x1F);
    fc->cart->setchr1(0x1C00, DRegs[5] & 0x1F);
    fc->cart->setprg8(0x8000, DRegs[6] & 0x1F);
    fc->cart->setprg8(0xa000, DRegs[7] & 0x1F);
    toot();
  }

  void Mapper95_write(DECLFW_ARGS) {
    switch (A & 0xF001) {
      case 0x8000: cmd = V; break;
      case 0x8001:
	switch (cmd & 0x07) {
	  case 0: DRegs[0] = (V & 0x3F) >> 1; break;
	  case 1: DRegs[1] = (V & 0x3F) >> 1; break;
	  case 2: DRegs[2] = V & 0x3F; break;
	  case 3: DRegs[3] = V & 0x3F; break;
	  case 4: DRegs[4] = V & 0x3F; break;
	  case 5: DRegs[5] = V & 0x3F; break;
	  case 6: DRegs[6] = V & 0x3F; break;
	  case 7: DRegs[7] = V & 0x3F; break;
	}
	Sync();
    }
  }

  int ppu_last = -1;
  void DragonBust_PPU(uint32 A) {
    if (A >= 0x2000) return;

    A >>= 10;
    lastA = A;
    // 'z' used to be static, but there seems to
    // be no reason for that. -tom7
    uint8 ppu_z = MirCache[A];
    if (ppu_z != ppu_last) {
      fc->ines->onemir(ppu_z);
      ppu_last = ppu_z;
    }
  }

  void Power() override {
    memset(DRegs, 0x3F, 8);
    DRegs[0] = DRegs[1] = 0x1F;

    Sync();

    fc->cart->setprg8(0xc000, 0x3E);
    fc->cart->setprg8(0xe000, 0x3F);

    fc->fceu->SetReadHandler(0x8000, 0xffff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
      ((Mapper95*)fc->fceu->cartiface)->Mapper95_write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper95*)fc->fceu->cartiface)->Sync();
  }

  Mapper95(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->PPU_hook = [](FC *fc, uint32 a) {
      ((Mapper95*)fc->fceu->cartiface)->DragonBust_PPU(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
      {DRegs, 8, "DREG"}, {&cmd, 1, "CMD0"}, {&lastA, 1, "LAST"}});
  }
};
}

CartInterface *Mapper95_Init(FC *fc, CartInfo *info) {
  return new Mapper95(fc, info);
}
