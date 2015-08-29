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
struct Mapper252 : public CartInterface {
  uint8 creg[8] = {}, preg[2] = {};
  int32 IRQa = 0, IRQCount = 0, IRQClock = 0, IRQLatch = 0;
  uint8 *WRAM = nullptr;
  uint8 *CHRRAM = nullptr;

  void Sync() {
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0x8000, preg[0]);
    fc->cart->setprg8(0xa000, preg[1]);
    fc->cart->setprg8(0xc000, ~1);
    fc->cart->setprg8(0xe000, ~0);
    for (uint8 i = 0; i < 8; i++)
      if ((creg[i] == 6) || (creg[i] == 7))
	fc->cart->setchr1r(0x10, i << 10, creg[i] & 1);
      else
	fc->cart->setchr1(i << 10, creg[i]);
  }

  void M252Write(DECLFW_ARGS) {
    if ((A >= 0xB000) && (A <= 0xEFFF)) {
      uint8 ind = ((((A & 8) | (A >> 8)) >> 3) + 2) & 7;
      uint8 sar = A & 4;
      creg[ind] = (creg[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
      Sync();
    } else
      switch (A & 0xF00C) {
	case 0x8000:
	case 0x8004:
	case 0x8008:
	case 0x800C:
	  preg[0] = V;
	  Sync();
	  break;
	case 0xA000:
	case 0xA004:
	case 0xA008:
	case 0xA00C:
	  preg[1] = V;
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
      ((Mapper252*)fc->fceu->cartiface)->M252Write(DECLFW_FORWARD);
    });
  }

  void M252IRQ(int a) {
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

  void Close() override {
    free(WRAM);
    free(CHRRAM);
    WRAM = CHRRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper252 *)fc->fceu->cartiface)->Sync();
  }

  Mapper252(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper252 *)fc->fceu->cartiface)->M252IRQ(a);
    };

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
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{creg, 8, "CREG"},
	                 {preg, 2, "PREG"},
			 {&IRQa, 4, "IRQA"},
			 {&IRQCount, 4, "IRQC"},
			 {&IRQLatch, 4, "IRQL"},
			 {&IRQClock, 4, "IRQK"}});
  }
};
}

CartInterface *Mapper252_Init(FC *fc, CartInfo *info) {
  return new Mapper252(fc, info);
}
