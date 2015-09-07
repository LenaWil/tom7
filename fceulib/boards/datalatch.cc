/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
#include "../ines.h"

static constexpr uint32 WRAMSIZE = 8192;

struct DataLatch : public CartInterface {
  using CartInterface::CartInterface;
  
  uint8 latch = 0, latchinit = 0, bus_conflict = 0;
  uint16 addrreg0 = 0, addrreg1 = 0;
  uint8 *WRAM = nullptr;

  // mapper-specific sync
  virtual void WSync() {}

  static DECLFW(LatchWrite) {
    return ((DataLatch*)fc->fceu->cartiface)->LatchWrite_Direct(DECLFW_FORWARD);
  }
      
  DECLFW_RET LatchWrite_Direct(DECLFW_ARGS) {
    //	FCEU_printf("bs %04x %02x\n",A,V);
    if (bus_conflict)
      latch = V & Cart::CartBR(fc, A);
    else
      latch = V;
    WSync();
  }

  void Power() override {
    latch = latchinit;
    WSync();
    if (WRAM) {
      fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
      fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    } else {
      fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    }
    fc->fceu->SetWriteHandler(addrreg0, addrreg1, LatchWrite);
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    DataLatch *me = ((DataLatch*)fc->fceu->cartiface);
    me->WSync();
  }

  DataLatch(FC *fc, CartInfo *info, uint8 init,
	    uint16 adr0, uint16 adr1, uint8 wram_flag, uint8 busc)
    : CartInterface(fc) {
    bus_conflict = busc;
    latchinit = init;
    addrreg0 = adr0;
    addrreg1 = adr1;
    fc->fceu->GameStateRestore = StateRestore;
    if (wram_flag) {
      WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
      fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
      if (info->battery) {
	info->SaveGame[0] = WRAM;
	info->SaveGameLen[0] = WRAMSIZE;
      }
      fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    }
    fc->state->AddExState(&latch, 1, 0, "LATC");
    fc->state->AddExState(&bus_conflict, 1, 0, "BUSC");
  }

  // Used by NROM. Note it does not set GameStateRestore
  // or save the latch, for example? But this is what NROM_Init did.
  DataLatch(FC *fc) : CartInterface(fc) {}
};

//------------------ Map 0 ---------------------------

struct NROM : public DataLatch {
  void Power() override {
    fc->cart->setprg8r(
	0x10, 0x6000,
	0);  // Famili BASIC (v3.0) need it (uses only 4KB), FP-BASIC uses 8KB
    fc->cart->setprg16(0x8000, 0);
    fc->cart->setprg16(0xC000, ~0);
    fc->cart->setchr8(0);

    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  NROM(FC *fc, CartInfo *info) : DataLatch(fc) {
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  }
};

CartInterface *NROM_Init(FC *fc, CartInfo *info) {
  return new NROM(fc, info);
}

//------------------ Map 2 ---------------------------

struct UNROM : public DataLatch {
  using DataLatch::DataLatch;
  uint32 mirror_in_use = 0;
  void WSync() override {
    if (fc->cart->PRGsize[0] <= 128 * 1024) {
      fc->cart->setprg16(0x8000, latch & 0x7);
      if (latch & 8) mirror_in_use = 1;
      if (mirror_in_use) {
	// Higway Star Hacked mapper
	fc->cart->setmirror(((latch >> 3) & 1) ^ 1);
      }
    } else {
      fc->cart->setprg16(0x8000, latch & 0xf);
    }
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(0);
  }
};

CartInterface *UNROM_Init(FC *fc, CartInfo *info) {
  return new UNROM(fc, info, 0, 0x8000, 0xFFFF, 0, 1);
}

//------------------ Map 3 ---------------------------

struct CNROM : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setchr8(latch);
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setprg8r(0x10, 0x6000, 0);  // Hayauchy IGO uses 2Kb or RAM
  }
};

CartInterface *CNROM_Init(FC *fc, CartInfo *info) {
  return new CNROM(fc, info, 0, 0x8000, 0xFFFF, 1, 1);
}

//------------------ Map 7 ---------------------------

struct ANROM : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, latch & 0xf);
    fc->cart->setmirror(MI_0 + ((latch >> 4) & 1));
    fc->cart->setchr8(0);
  }
};

CartInterface *ANROM_Init(FC *fc, CartInfo *info) {
  return new ANROM(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 8 ---------------------------

struct Mapper8 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, latch >> 3);
    fc->cart->setprg16(0xc000, 1);
    fc->cart->setchr8(latch & 3);
  }
};

CartInterface *Mapper8_Init(FC *fc, CartInfo *info) {
  return new Mapper8(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 11 ---------------------------

struct Mapper11 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, latch & 0xf);
    fc->cart->setchr8(latch >> 4);
  }
};

CartInterface *Mapper11_Init(FC *fc, CartInfo *info) {
  return new Mapper11(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

CartInterface *Mapper144_Init(FC *fc, CartInfo *info) {
  return new Mapper11(fc, info, 0, 0x8001, 0xFFFF, 0, 0);
}

//------------------ Map 13 ---------------------------

struct CPROM : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setchr4(0x0000, 0);
    fc->cart->setchr4(0x1000, latch & 3);
    fc->cart->setprg32(0x8000, 0);
  }
};

CartInterface *CPROM_Init(FC *fc, CartInfo *info) {
  return new CPROM(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 36 ---------------------------

struct Mapper36 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, latch >> 4);
    fc->cart->setchr8(latch & 0xF);
  }
};

CartInterface *Mapper36_Init(FC *fc, CartInfo *info) {
  return new Mapper36(fc, info, 0, 0x8400, 0xfffe, 0, 0);
}

//------------------ Map 38 ---------------------------

struct Mapper38 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, latch & 3);
    fc->cart->setchr8(latch >> 2);
  }
};

CartInterface *Mapper38_Init(FC *fc, CartInfo *info) {
  return new Mapper38(fc, info, 0, 0x7000, 0x7FFF, 0, 0);
}

//------------------ Map 66, 140 ---------------------------

struct MHROM : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, latch >> 4);
    fc->cart->setchr8(latch & 0xf);
  }
};

CartInterface *MHROM_Init(FC *fc, CartInfo *info) {
  return new MHROM(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

CartInterface *Mapper140_Init(FC *fc, CartInfo *info) {
  return new MHROM(fc, info, 0, 0x6000, 0x7FFF, 0, 0);
}

//------------------ Map 70 ---------------------------

struct Mapper70 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, latch >> 4);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(latch & 0xf);
  }
};

CartInterface *Mapper70_Init(FC *fc, CartInfo *info) {
  return new Mapper70(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 78 ---------------------------
/* Should be two separate emulation functions for this "mapper".  Sigh.  URGE TO
 * KILL RISING. */
struct Mapper78 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, (latch & 7));
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(latch >> 4);
    fc->cart->setmirror(MI_0 + ((latch >> 3) & 1));
  }
};

CartInterface *Mapper78_Init(FC *fc, CartInfo *info) {
  return new Mapper78(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 86 ---------------------------

struct Mapper86 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch >> 4) & 3);
    fc->cart->setchr8((latch & 3) | ((latch >> 4) & 4));
  }
};

CartInterface *Mapper86_Init(FC *fc, CartInfo *info) {
  return new Mapper86(fc, info, ~0, 0x6000, 0x6FFF, 0, 0);
}

//------------------ Map 87 ---------------------------

struct Mapper87 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(((latch >> 1) & 1) | ((latch << 1) & 2));
  }
};

CartInterface *Mapper87_Init(FC *fc, CartInfo *info) {
  return new Mapper87(fc, info, ~0, 0x6000, 0xFFFF, 0, 0);
}

//------------------ Map 89 ---------------------------

struct Mapper89 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, (latch >> 4) & 7);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8((latch & 7) | ((latch >> 4) & 8));
    fc->cart->setmirror(MI_0 + ((latch >> 3) & 1));
  }
};

CartInterface *Mapper89_Init(FC *fc, CartInfo *info) {
  return new Mapper89(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 93 ---------------------------

struct SUNSOFTUNROM : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, latch >> 4);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(0);
  }
};

CartInterface *SUNSOFT_UNROM_Init(FC *fc, CartInfo *info) {
  return new SUNSOFTUNROM(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 94 ---------------------------

struct Mapper94 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, latch >> 2);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(0);
  }
};

CartInterface *Mapper94_Init(FC *fc, CartInfo *info) {
  return new Mapper94(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 97 ---------------------------

struct Mapper97 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setchr8(0);
    fc->cart->setprg16(0x8000, ~0);
    fc->cart->setprg16(0xc000, latch & 15);
    switch (latch >> 6) {
      case 0: break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_V); break;
      case 3: break;
    }
    fc->cart->setchr8(((latch >> 1) & 1) | ((latch << 1) & 2));
  }
};

CartInterface *Mapper97_Init(FC *fc, CartInfo *info) {
  return new Mapper97(fc, info, ~0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 101 ---------------------------

struct Mapper101 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(latch);
  }
};

CartInterface *Mapper101_Init(FC *fc, CartInfo *info) {
  return new Mapper101(fc, info, ~0, 0x6000, 0x7FFF, 0, 0);
}

//------------------ Map 107 ---------------------------

struct Mapper107 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch >> 1) & 3);
    fc->cart->setchr8(latch & 7);
  }
};

CartInterface *Mapper107_Init(FC *fc, CartInfo *info) {
  return new Mapper107(fc, info, ~0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 113 ---------------------------

struct Mapper113 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch >> 3) & 7);
    fc->cart->setchr8(((latch >> 3) & 8) | (latch & 7));
    //	fc->cart->setmirror(latch>>7); // only for HES 6in1
  }
};

CartInterface *Mapper113_Init(FC *fc, CartInfo *info) {
  return new Mapper113(fc, info, 0, 0x4100, 0x7FFF, 0, 0);
}


//------------------ Map 152 ---------------------------

struct Mapper152 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, (latch >> 4) & 7);
    fc->cart->setprg16(0xc000, ~0);
    fc->cart->setchr8(latch & 0xf);
    fc->cart->setmirror(MI_0 +
			((latch >> 7) & 1)); /* Saint Seiya...hmm. */
  }
};

CartInterface *Mapper152_Init(FC *fc, CartInfo *info) {
  return new Mapper152(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 180 ---------------------------

struct Mapper180 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, 0);
    fc->cart->setprg16(0xc000, latch);
    fc->cart->setchr8(0);
  }
};

CartInterface *Mapper180_Init(FC *fc, CartInfo *info) {
  return new Mapper180(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 184 ---------------------------

struct Mapper184 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setchr4(0x0000, latch);
    fc->cart->setchr4(0x1000, latch >> 4);
    fc->cart->setprg32(0x8000, 0);
  }
};

CartInterface *Mapper184_Init(FC *fc, CartInfo *info) {
  return new Mapper184(fc, info, 0, 0x6000, 0x7FFF, 0, 0);
}

//------------------ Map 203 ---------------------------

struct Mapper203 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, (latch >> 2) & 3);
    fc->cart->setprg16(0xC000, (latch >> 2) & 3);
    fc->cart->setchr8(latch & 3);
  }
};

CartInterface *Mapper203_Init(FC *fc, CartInfo *info) {
  return new Mapper203(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 240 ---------------------------

struct Mapper240 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, latch >> 4);
    fc->cart->setchr8(latch & 0xf);
  }
};

CartInterface *Mapper240_Init(FC *fc, CartInfo *info) {
  return new Mapper240(fc, info, 0, 0x4020, 0x5FFF, 1, 0);
}

//------------------ Map 241 ---------------------------
// Mapper 7 mostly, but with SRAM or maybe prot circuit
// figure out, which games do need 5xxx area reading

struct Mapper241 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, latch);
  }
};

CartInterface *Mapper241_Init(FC *fc, CartInfo *info) {
  return new Mapper241(fc, info, 0, 0x8000, 0xFFFF, 1, 0);
}

//------------------ A65AS ---------------------------

// actually, there is two cart in one... First have extra mirroring
// mode (one screen) and 32K bankswitching, second one have only
// 16 bankswitching mode and normal mirroring... But there is no any
// correlations between modes and they can be used in one mapper code.

struct BMCA65AS : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    if (latch & 0x40) {
      fc->cart->setprg32(0x8000, (latch >> 1) & 0x0F);
    } else {
      fc->cart->setprg16(0x8000, ((latch & 0x30) >> 1) | (latch & 7));
      fc->cart->setprg16(0xC000, ((latch & 0x30) >> 1) | 7);
    }
    fc->cart->setchr8(0);
    if (latch & 0x80)
      fc->cart->setmirror(MI_0 + (((latch >> 5) & 1)));
    else
      fc->cart->setmirror(((latch >> 3) & 1) ^ 1);
  }
};

CartInterface *BMCA65AS_Init(FC *fc, CartInfo *info) {
  return new BMCA65AS(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ BMC-11160 ---------------------------
// Simple BMC discrete mapper by TXC

struct BMC11160 : public DataLatch {
  using DataLatch::DataLatch;
  void WSync() override {
    uint32 bank = (latch >> 4) & 7;
    fc->cart->setprg32(0x8000, bank);
    fc->cart->setchr8((bank << 2) | (latch & 3));
    fc->cart->setmirror((latch >> 7) & 1);
  }
};

CartInterface *BMC11160_Init(FC *fc, CartInfo *info) {
  return new BMC11160(fc, info, 0, 0x8000, 0xFFFF, 0, 0);
}

