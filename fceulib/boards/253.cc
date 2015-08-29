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

static constexpr int CHRRAMSIZE = 2048;
static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper253 : public CartInterface {
  uint8 chrlo[8] = {}, chrhi[8] = {}, prg[2] = {}, mirr = 0, vlock = 0;
  int32 IRQa = 0, IRQCount = 0, IRQLatch = 0, IRQClock = 0;
  uint8 *WRAM = nullptr;
  uint8 *CHRRAM = nullptr;

  void Sync() {
    uint8 i;
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0x8000, prg[0]);
    fc->cart->setprg8(0xa000, prg[1]);
    fc->cart->setprg8(0xc000, ~1);
    fc->cart->setprg8(0xe000, ~0);
    for (i = 0; i < 8; i++) {
      uint32 chr = chrlo[i] | (chrhi[i] << 8);
      if (chrlo[i] == 0xc8) {
	vlock = 0;
	continue;
      } else if (chrlo[i] == 0x88) {
	vlock = 1;
	continue;
      }
      if (((chrlo[i] == 4) || (chrlo[i] == 5)) && !vlock)
	fc->cart->setchr1r(0x10, i << 10, chr & 1);
      else
	fc->cart->setchr1(i << 10, chr);
    }
    switch (mirr) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_0); break;
      case 3: fc->cart->setmirror(MI_1); break;
    }
  }

  void M253Write(DECLFW_ARGS) {
    if ((A >= 0xB000) && (A <= 0xE00C)) {
      uint8 ind = ((((A & 8) | (A >> 8)) >> 3) + 2) & 7;
      uint8 sar = A & 4;
      chrlo[ind] = (chrlo[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
      if (A & 4) chrhi[ind] = V >> 4;
      Sync();
    } else
      switch (A) {
	case 0x8010:
	  prg[0] = V;
	  Sync();
	  break;
	case 0xA010:
	  prg[1] = V;
	  Sync();
	  break;
	case 0x9400:
	  mirr = V & 3;
	  Sync();
	  break;
	case 0xF000:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQLatch &= 0xF0;
	  IRQLatch |= V & 0xF;
	  break;
	case 0xF004:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQLatch &= 0x0F;
	  IRQLatch |= V << 4;
	  break;
	case 0xF008:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQClock = 0;
	  IRQCount = IRQLatch;
	  IRQa = V & 2;
	  break;
      }
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper253*)fc->fceu->cartiface)->M253Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    free(CHRRAM);
    WRAM = CHRRAM = nullptr;
  }

  void M253IRQ(int a) {
    static constexpr int LCYCS = 341;
    if (IRQa) {
      IRQClock += a * 3;
      if (IRQClock >= LCYCS) {
	while (IRQClock >= LCYCS) {
	  IRQClock -= LCYCS;
	  IRQCount++;
	  if (IRQCount & 0x100) {
	    fc->X->IRQBegin(FCEU_IQEXT);
	    IRQCount = IRQLatch;
	  }
	}
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper253 *)fc->fceu->cartiface)->Sync();
  }
  Mapper253(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper253 *)fc->fceu->cartiface)->M253IRQ(a);
    };
    fc->fceu->GameStateRestore = StateRestore;

    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSIZE);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }

    fc->state->AddExVec({{chrlo, 8, "CHRL"}, {chrhi, 8, "CHRH"},
			 {prg, 2, "PRGR"}, {&mirr, 1, "MIRR"},
			 {&vlock, 1, "VLCK"}, {&IRQa, 4, "IRQA"},
			 {&IRQCount, 4, "IRQC"}, {&IRQLatch, 4, "IRQL"},
			 {&IRQClock, 4, "IRQK"}});
    
  }
};
}

CartInterface *Mapper253_Init(FC *fc, CartInfo *info) {
  return new Mapper253(fc, info);
}
