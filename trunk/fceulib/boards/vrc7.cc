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

namespace {
struct UNLVRC7 : public CartInterface {
  uint8 prg[3] = {}, chr[8] = {}, mirr = 0;
  uint8 IRQLatch = 0, IRQa = 0, IRQd = 0;
  uint32 IRQCount = 0, CycleCount = 0;

  void Sync() {
    fc->cart->setprg8(0x8000, prg[0]);
    fc->cart->setprg8(0xa000, prg[1]);
    fc->cart->setprg8(0xc000, prg[2]);
    fc->cart->setprg8(0xe000, ~0);
    for (uint8 i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chr[i]);
    switch (mirr & 3) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_0); break;
      case 3: fc->cart->setmirror(MI_1); break;
    }
  }

  void UNLVRC7Write(DECLFW_ARGS) {
    switch (A & 0xF008) {
      case 0x8000:
	prg[0] = V;
	Sync();
	break;
      case 0x8008:
	prg[1] = V;
	Sync();
	break;
      case 0x9000:
	prg[2] = V;
	Sync();
	break;
      case 0xa000:
	chr[0] = V;
	Sync();
	break;
      case 0xa008:
	chr[1] = V;
	Sync();
	break;
      case 0xb000:
	chr[2] = V;
	Sync();
	break;
      case 0xb008:
	chr[3] = V;
	Sync();
	break;
      case 0xc000:
	chr[4] = V;
	Sync();
	break;
      case 0xc008:
	chr[5] = V;
	Sync();
	break;
      case 0xd000:
	chr[6] = V;
	Sync();
	break;
      case 0xd008:
	chr[7] = V;
	Sync();
	break;
      case 0xe000:
	mirr = V;
	Sync();
	break;
      case 0xe008:
	IRQLatch = V;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xf000:
	IRQa = V & 2;
	IRQd = V & 1;
	if (V & 2) IRQCount = IRQLatch;
	CycleCount = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xf008:
	if (IRQd)
	  IRQa = 1;
	else
	  IRQa = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
    }
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((UNLVRC7*)fc->fceu->cartiface)->UNLVRC7Write(DECLFW_FORWARD);
    });
  }

  void UNLVRC7IRQHook(int a) {
    if (IRQa) {
      CycleCount += a * 3;
      while (CycleCount >= 341) {
	CycleCount -= 341;
	IRQCount++;
	if (IRQCount == 248) {
	  fc->X->IRQBegin(FCEU_IQEXT);
	  IRQCount = IRQLatch;
	}
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLVRC7 *)fc->fceu->cartiface)->Sync();
  }

  UNLVRC7(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((UNLVRC7 *)fc->fceu->cartiface)->UNLVRC7IRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{prg, 3, "PRG0"}, {chr, 8, "CHR0"}, {&mirr, 1, "MIRR"},
	{&IRQa, 1, "IRQA"}, {&IRQd, 1, "IRQD"}, {&IRQLatch, 1, "IRQC"},
	{&IRQCount, 4, "IRQC"}, {&CycleCount, 4, "CYCC"}});
  }
};
}
CartInterface *UNLVRC7_Init(FC *fc, CartInfo *info) {
  return new UNLVRC7(fc, info);
}
