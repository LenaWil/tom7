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
 *
 * Wario Land II (Kirby hack)
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct UNLSC127 : public CartInterface {
  uint8 reg[8] = {}, chr[8] = {};
  uint8 *WRAM = nullptr;
  uint16 IRQCount = 0, IRQa = 0;

  void Sync() {
    fc->cart->setprg8(0x8000, reg[0]);
    fc->cart->setprg8(0xA000, reg[1]);
    fc->cart->setprg8(0xC000, reg[2]);
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chr[i]);
    fc->cart->setmirror(reg[3] ^ 1);
  }

  void UNLSC127Write(DECLFW_ARGS) {
    switch (A) {
      case 0x8000: reg[0] = V; break;
      case 0x8001: reg[1] = V; break;
      case 0x8002: reg[2] = V; break;
      case 0x9000: chr[0] = V; break;
      case 0x9001: chr[1] = V; break;
      case 0x9002: chr[2] = V; break;
      case 0x9003: chr[3] = V; break;
      case 0x9004: chr[4] = V; break;
      case 0x9005: chr[5] = V; break;
      case 0x9006: chr[6] = V; break;
      case 0x9007: chr[7] = V; break;
      case 0xC002:
	IRQa = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xC005: IRQCount = V; break;
      case 0xC003: IRQa = 1; break;
      case 0xD001: reg[3] = V; break;
    }
    Sync();
  }

  void Power() override {
    Sync();
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0xE000, ~0);
    fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((UNLSC127*)fc->fceu->cartiface)->UNLSC127Write(DECLFW_FORWARD);
      });
  }

  void UNLSC127IRQ() {
    if (IRQa) {
      IRQCount--;
      if (IRQCount == 0) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
      }
    }
  }

  void Reset() override {}

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLSC127 *)fc->fceu->cartiface)->Sync();
  }
  
  UNLSC127(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((UNLSC127 *)fc->fceu->cartiface)->UNLSC127IRQ();
    };
    fc->fceu->GameStateRestore = StateRestore;
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    fc->state->AddExVec({{reg, 8, "REGS"},
	                 {chr, 8, "CHRS"},
			 {&IRQCount, 16, "IRQc"},
			 {&IRQa, 16, "IRQa"}});
  }
};
}

CartInterface *UNLSC127_Init(FC *fc, CartInfo *info) {
  return new UNLSC127(fc, info);
}
