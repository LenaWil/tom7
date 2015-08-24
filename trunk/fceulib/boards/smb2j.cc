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
 * Super Mario Bros 2 J alt version
 * as well as "Voleyball" FDS conversion, bank layout is similar but no
 * bankswitching and CHR ROM present
 *
 * mapper seems wrongly researched by me ;( it should be mapper 43 modification
 */

#include "mapinc.h"

namespace {
struct UNLSMB2J : public CartInterface {
  uint8 prg = 0, IRQa = 0;
  uint16 IRQCount = 0;

  void Sync() {
    fc->cart->setprg4r(1, 0x5000, 1);
    fc->cart->setprg8r(1, 0x6000, 1);
    fc->cart->setprg32(0x8000, prg);
    fc->cart->setchr8(0);
  }

  void UNLSMB2JWrite(DECLFW_ARGS) {
    if (A == 0x4022) {
      prg = V & 1;
      Sync();
    }
    if (A == 0x4122) {
      IRQa = V;
      IRQCount = 0;
      fc->X->IRQEnd(FCEU_IQEXT);
    }
  }

  void Power() override {
    prg = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x5000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4020, 0xffff, [](DECLFW_ARGS) {
	((UNLSMB2J*)fc->fceu->cartiface)->UNLSMB2JWrite(DECLFW_FORWARD);
      });
  }

  void Reset() override {
    prg = ~0;
    Sync();
  }

  void UNLSMB2JIRQHook(int a) {
    if (IRQa) {
      IRQCount += a * 3;
      if ((IRQCount >> 12) == IRQa) fc->X->IRQBegin(FCEU_IQEXT);
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLSMB2J *)fc->fceu->cartiface)->Sync();
  }

  UNLSMB2J(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((UNLSMB2J *)fc->fceu->cartiface)->UNLSMB2JIRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&prg, 1, "PRG0"}, {&IRQa, 1, "IRQA"}, {&IRQCount, 2, "IRQC"}});
  }
};
}

CartInterface *UNLSMB2J_Init(FC *fc, CartInfo *info) {
  return new UNLSMB2J(fc, info);
}
