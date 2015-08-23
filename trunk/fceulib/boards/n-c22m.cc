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
 * Mortal Kombat 2 YOKO */

#include "mapinc.h"

// ?
// #include "mmc3.h"

namespace {
struct UNLCN22M : public CartInterface {
  uint8 reg[8] = {};

  void Sync() {
    //  FCEU_printf("(%02x, %02x)\n",reg[3],reg[4]);
    fc->cart->setprg8(0x8000, reg[0]);
    fc->cart->setprg8(0xA000, reg[1]);
    fc->cart->setprg8(0xC000, reg[2]);
    fc->cart->setprg8(0xE000, ~0);
    //  setchr2(0x0000,reg[3]);
    //  setchr2(0x0800,reg[4]);
    //  setchr2(0x1000,reg[5]);
    //  setchr2(0x1800,reg[6]);
    fc->cart->setchr2(0x0000, reg[3]);
    fc->cart->setchr2(0x0800, reg[4]);
    fc->cart->setchr2(0x1000, reg[5]);
    fc->cart->setchr2(0x1800, reg[6]);
  }

  void MCN22MWrite(DECLFW_ARGS) {
    // FCEU_printf("bs %04x %02x\n",A,V);
    switch (A) {
    case 0x8c00:
    case 0x8c01:
    case 0x8c02: reg[A & 3] = V; break;
    case 0x8d10: reg[3] = V; break;
    case 0x8d11: reg[4] = V; break;
    case 0x8d16: reg[5] = V; break;
    case 0x8d17: reg[6] = V; break;
    }
    Sync();
  }

  void Power() override {
    reg[0] = reg[1] = reg[2] = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((UNLCN22M*)fc->fceu->cartiface)->MCN22MWrite(DECLFW_FORWARD);
      });
  }
  /*
    static void MCN22MIRQHook()
    {
    int count = IRQCount;
    if(!count || IRQReload)
    {
    IRQCount = IRQLatch;
    IRQReload = 0;
    }
    else
    IRQCount--;
    if(!IRQCount)
    {
    if(IRQa)
    {
    fc->X->IRQBegin(FCEU_IQEXT);
    }
    }
    }
  */
  static void StateRestore(FC *fc, int version) {
    ((UNLCN22M*)fc->fceu->cartiface)->Sync();
  }

  UNLCN22M(FC *fc, CartInfo *info) : CartInterface(fc) {
    //  GameHBIRQHook=MCN22MIRQHook;
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{reg, 8, "REGS"}});
  }
};
}

CartInterface *UNLCN22M_Init(FC *fc, CartInfo *info) {
  return new UNLCN22M(fc, info);
}
