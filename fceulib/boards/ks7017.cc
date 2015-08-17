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
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct UNLKS7017 : public CartInterface {
  uint8 reg = 0, mirr = 0;
  int32 IRQa = 0, IRQCount = 0, IRQLatch = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setprg16(0x8000, reg);
    fc->cart->setprg16(0xC000, 2);
    fc->cart->setmirror(mirr);
  }

  void UNLKS7017Write(DECLFW_ARGS) {
    //  FCEU_printf("bs %04x %02x\n",A,V);
    if ((A & 0xFF00) == 0x4A00) {
      reg = ((A >> 2) & 3) | ((A >> 4) & 4);
    } else if ((A & 0xFF00) == 0x5100) {
      Sync();
    } else if (A == 0x4020) {
      fc->X->IRQEnd(FCEU_IQEXT);
      IRQCount &= 0xFF00;
      IRQCount |= V;
    } else if (A == 0x4021) {
      fc->X->IRQEnd(FCEU_IQEXT);
      IRQCount &= 0xFF;
      IRQCount |= V << 8;
      IRQa = 1;
    } else if (A == 0x4025) {
      mirr = ((V & 8) >> 3) ^ 1;
    }
  }

  DECLFR_RET FDSRead4030(DECLFR_ARGS) {
    fc->X->IRQEnd(FCEU_IQEXT);
    return fc->X->IRQlow & FCEU_IQEXT ? 1 : 0;
  }

  void UNL7017IRQ(int a) {
    if (IRQa) {
      IRQCount -= a;
      if (IRQCount <= 0) {
	IRQa = 0;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  void Power() override {
    Sync();
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x4030, 0x4030, [](DECLFR_ARGS) {
      return ((UNLKS7017*)fc->fceu->cartiface)->FDSRead4030(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4020, 0x5FFF, [](DECLFW_ARGS) {
      ((UNLKS7017*)fc->fceu->cartiface)->UNLKS7017Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLKS7017*)fc->fceu->cartiface)->Sync();
  }

  UNLKS7017(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((UNLKS7017*)fc->fceu->cartiface)->UNL7017IRQ(a);
    };

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&mirr, 1, "MIRR"}, {&reg, 1, "REGS"},
			 {&IRQa, 4, "IRQA"}, {&IRQCount, 4, "IRQC"},
			 {&IRQLatch, 4, "IRQL"}});
  }

};
}

CartInterface *UNLKS7017_Init(FC *fc, CartInfo *info) {
  return new UNLKS7017(fc, info);
}
