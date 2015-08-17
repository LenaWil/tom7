/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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

// According to nestopia, BTL_SMB2_C, otherwise known as UNL-SMB2J

#include "mapinc.h"

namespace {
struct Mapper43 : public CartInterface {
  uint8 reg = 0;
  uint32 IRQCount = 0, IRQa = 0;

  void Sync() {
    // Only YS-612 advdnced version
    fc->cart->setprg4(0x5000, 16);
    fc->cart->setprg8(0x6000, 2);
    fc->cart->setprg8(0x8000, 1);
    fc->cart->setprg8(0xa000, 0);
    fc->cart->setprg8(0xc000, reg);
    fc->cart->setprg8(0xe000, 9);
    fc->cart->setchr8(0);
  }

  void M43Write(DECLFW_ARGS) {
    //  int transo[8]={4,3,4,4,4,7,5,6};
    // According to hardware tests:
    static constexpr int transo[8] = {4, 3, 5, 3, 6, 3, 7, 3};
    switch (A & 0xf1ff) {
      case 0x4022:
	reg = transo[V & 7];
	Sync();
	break;
      case 0x8122:  // hacked version
      case 0x4122:
	IRQa = V & 1;
	fc->X->IRQEnd(FCEU_IQEXT);
	IRQCount = 0;
	break;  // original version
    }
  }

  void Power() override {
    reg = 0;
    Sync();
    fc->fceu->SetReadHandler(0x5000, 0xffff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4020, 0xffff, [](DECLFW_ARGS) {
      ((Mapper43*)fc->fceu->cartiface)->M43Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {}

  void M43IRQHook(int a) {
    IRQCount += a;
    if (IRQa)
      if (IRQCount >= 4096) {
	IRQa = 0;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper43*)fc->fceu->cartiface)->Sync();
  }

  Mapper43(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper43*)fc->fceu->cartiface)->M43IRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&IRQCount, 4, "IRQC"}, {&IRQa, 1, "IRQA"}, {&reg, 1, "REGS"}});
  }
};
}
  
CartInterface *Mapper43_Init(FC *fc, CartInfo *info) {
  return new Mapper43(fc, info);
}
