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
struct VRC : public CartInterface {

  const bool isPirate;
  const bool is22;
  uint16 IRQCount = 0;
  uint8 IRQLatch = 0, IRQa = 0;
  uint8 prgreg[2] = {}, chrreg[8] = {};
  uint16 chrhi[8] = {};
  uint8 regcmd = 0, irqcmd = 0, mirr = 0, big_bank = 0;
  uint16 acount = 0;
  uint16 weirdo = 0;

  uint8 *WRAM = nullptr;

  void Sync() {
    if (regcmd & 2) {
      fc->cart->setprg8(0xC000, prgreg[0] | big_bank);
      fc->cart->setprg8(0x8000, ((~1) & 0x1F) | big_bank);
    } else {
      fc->cart->setprg8(0x8000, prgreg[0] | big_bank);
      fc->cart->setprg8(0xC000, ((~1) & 0x1F) | big_bank);
    }
    fc->cart->setprg8(0xA000, prgreg[1] | big_bank);
    fc->cart->setprg8(0xE000, ((~0) & 0x1F) | big_bank);
    if (fc->unif->UNIFchrrama)
      fc->cart->setchr8(0);
    else {
      uint8 i;
      if (!weirdo)
	for (i = 0; i < 8; i++)
	  fc->cart->setchr1(i << 10, (chrhi[i] | chrreg[i]) >> is22);
      else {
	fc->cart->setchr1(0x0000, 0xFC);
	fc->cart->setchr1(0x0400, 0xFD);
	fc->cart->setchr1(0x0800, 0xFF);
	weirdo--;
      }
    }
    switch (mirr & 0x3) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_0); break;
      case 3: fc->cart->setmirror(MI_1); break;
    }
  }

  void VRC24Write(DECLFW_ARGS) {
    A &= 0xF003;
    if ((A >= 0xB000) && (A <= 0xE003)) {
      if (fc->unif->UNIFchrrama) {
	// my personally many-in-one feature ;) just for support pirate cart
	// 2-in-1
	big_bank = (V & 8) << 2;
      } else {
	uint16 i = ((A >> 1) & 1) | ((A - 0xB000) >> 11);
	uint16 nibble = ((A & 1) << 2);
	chrreg[i] &= (0xF0) >> nibble;
	chrreg[i] |= (V & 0xF) << nibble;
	// another one many in one feature from pirate carts
	if (nibble) chrhi[i] = (V & 0x10) << 4;
      }
      Sync();
    } else {
      switch (A & 0xF003) {
	case 0x8000:
	case 0x8001:
	case 0x8002:
	case 0x8003:
	  if (!isPirate) {
	    prgreg[0] = V & 0x1F;
	    Sync();
	  }
	  break;
	case 0xA000:
	case 0xA001:
	case 0xA002:
	case 0xA003:
	  if (!isPirate)
	    prgreg[1] = V & 0x1F;
	  else {
	    prgreg[0] = (V & 0x1F) << 1;
	    prgreg[1] = ((V & 0x1F) << 1) | 1;
	  }
	  Sync();
	  break;
	case 0x9000:
	case 0x9001:
	  if (V != 0xFF) mirr = V;
	  Sync();
	  break;
	case 0x9002:
	case 0x9003:
	  regcmd = V;
	  Sync();
	  break;
	case 0xF000:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQLatch &= 0xF0;
	  IRQLatch |= V & 0xF;
	  break;
	case 0xF001:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQLatch &= 0x0F;
	  IRQLatch |= V << 4;
	  break;
	case 0xF002:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  acount = 0;
	  IRQCount = IRQLatch;
	  IRQa = V & 2;
	  irqcmd = V & 1;
	  break;
	case 0xF003:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQa = irqcmd;
	  break;
      }
    }
  }

  void M22Write(DECLFW_ARGS) {
    if (A == 0xC007) {
      // Ganbare Goemon Gaiden does strange things!!! at the end credits
      // quick dirty hack, seems there is no other games with such PCB, so
      // we never know if it will not work for something else lol
      weirdo = 8;
    }
    A |= ((A >> 2) & 0x3);
    // It's just swapped lines from 21 mapper
    VRC24Write(fc, (A & 0xF000) | ((A >> 1) & 1) | ((A << 1) & 2), V);
  }
  
  void VRC24IRQHook(int a) {
    static constexpr int LCYCS = 341;
    if (IRQa) {
      acount += a * 3;
      if (acount >= LCYCS) {
	while (acount >= LCYCS) {
	  acount -= LCYCS;
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
    ((VRC *)fc->fceu->cartiface)->Sync();
  }

  VRC(FC *fc, CartInfo *info, bool isp, bool is22) :
    CartInterface(fc), isPirate(isp), is22(is22) {
    fc->state->AddExVec({{prgreg, 2, "PREG"},
			 {chrreg, 8, "CREG"},
			 {chrhi, 16, "CRGH"},
			 {&regcmd, 1, "CMDR"},
			 {&irqcmd, 1, "CMDI"},
			 {&mirr, 1, "MIRR"},
			 {&big_bank, 1, "BIGB"},
			 {&IRQCount, 2, "IRQC"},
			 {&IRQLatch, 1, "IRQL"},
			 {&IRQa, 1, "IRQA"}});
    fc->fceu->GameStateRestore = StateRestore;
  }
};

struct Mapper21 : public VRC {
  void M21Write(DECLFW_ARGS) {
    A = (A & 0xF000) | ((A >> 1) & 0x3);
    // Ganbare Goemon Gaiden 2 - Tenka no Zaihou (J) [!] isn't mapper 21
    // actually, it's mapper 23 by wirings
    VRC24Write(fc, A, V);
  }
  
  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper21*)fc->fceu->cartiface)->M21Write(DECLFW_FORWARD);
    });
  }

  Mapper21(FC *fc, CartInfo *info) : VRC(fc, info, false, false) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper21 *)fc->fceu->cartiface)->VRC24IRQHook(a);
    };
  }
};

struct Mapper22 : public VRC {
  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper22*)fc->fceu->cartiface)->M22Write(DECLFW_FORWARD);
    });
  }

  Mapper22(FC *fc, CartInfo *info) : VRC(fc, info, false, true) {}
};

struct VRC24 : public VRC {
  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  VRC24(FC *fc, CartInfo *info, bool isp, bool is22) :
    VRC(fc, info, isp, is22) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((VRC24 *)fc->fceu->cartiface)->VRC24IRQHook(a);
    };

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }
  }
};

struct Mapper23 : public VRC24 {
  using VRC24::VRC24;
  void M23Write(DECLFW_ARGS) {
    A |= ((A >> 2) & 0x3) | ((A >> 4) & 0x3) | ((A >> 6) & 0x3);
    // actually there is many-in-one mapper source, some pirate or
    // licensed games use various address bits for registers
    VRC24Write(fc, A, V);
  }

  void Power() override {
    big_bank = 0x20;
    Sync();
    // Only two Goemon games are have
    // battery backed RAM, three more
    // shooters
    fc->cart->setprg8r(0x10, 0x6000, 0);  
    // (Parodius Da!, Gradius 2 and Crisis Force uses 2k or SRAM at
    // 6000-67FF only
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper23*)fc->fceu->cartiface)->M23Write(DECLFW_FORWARD);
    });
  }
};

struct Mapper25 : public VRC24 {
  using VRC24::VRC24;
  void Power() override {
    big_bank = 0x20;
    Sync();
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper25*)fc->fceu->cartiface)->M22Write(DECLFW_FORWARD);
    });
  }
};
}

CartInterface *Mapper21_Init(FC *fc, CartInfo *info) {
  return new Mapper21(fc, info);
}

CartInterface *Mapper22_Init(FC *fc, CartInfo *info) {
  return new Mapper22(fc, info);
}

CartInterface *Mapper23_Init(FC *fc, CartInfo *info) {
  return new Mapper23(fc, info, false, false);
}

CartInterface *Mapper25_Init(FC *fc, CartInfo *info) {
  return new Mapper25(fc, info, false, false);
}

CartInterface *UNLT230_Init(FC *fc, CartInfo *info) {
  return new Mapper23(fc, info, true, false);
}
