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

static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper106 : public CartInterface {
  uint8 reg[16] = {}, IRQa = 0;
  uint32 IRQCount = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setchr1(0x0000, reg[0] & 0xfe);
    fc->cart->setchr1(0x0400, reg[1] | 1);
    fc->cart->setchr1(0x0800, reg[2] & 0xfe);
    fc->cart->setchr1(0x0c00, reg[3] | 1);
    fc->cart->setchr1(0x1000, reg[4]);
    fc->cart->setchr1(0x1400, reg[5]);
    fc->cart->setchr1(0x1800, reg[6]);
    fc->cart->setchr1(0x1c00, reg[7]);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0x8000, (reg[0x8] & 0xf) | 0x10);
    fc->cart->setprg8(0xA000, (reg[0x9] & 0x1f));
    fc->cart->setprg8(0xC000, (reg[0xa] & 0x1f));
    fc->cart->setprg8(0xE000, (reg[0xb] & 0xf) | 0x10);
    fc->cart->setmirror((reg[0xc] & 1) ^ 1);
  }

  void M106Write(DECLFW_ARGS) {
    A &= 0xF;
    switch (A) {
      case 0xD:
	IRQa = 0;
	IRQCount = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xE: IRQCount = (IRQCount & 0xFF00) | V; break;
      case 0xF:
	IRQCount = (IRQCount & 0x00FF) | (V << 8);
	IRQa = 1;
	break;
      default:
	reg[A] = V;
	Sync();
	break;
    }
  }

  void Power() override {
    reg[8] = reg[9] = reg[0xa] = reg[0xb] = -1;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper106*)fc->fceu->cartiface)->M106Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {}

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  void M106CpuHook(int a) {
    if (IRQa) {
      IRQCount += a;
      if (IRQCount > 0x10000) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper106*)fc->fceu->cartiface)->Sync();
  }

  Mapper106(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper106*)fc->fceu->cartiface)->M106CpuHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({
	{&IRQa, 1, "IRQA"}, {&IRQCount, 4, "IRQC"}, {reg, 16, "REGS"}});
  }
};
}
 
CartInterface *Mapper106_Init(FC *fc, CartInfo *info) {
  return new Mapper106(fc, info);
}
