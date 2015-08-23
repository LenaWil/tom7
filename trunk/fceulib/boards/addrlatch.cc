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

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct AddrLatch : public CartInterface {
  uint16 latch = 0, latchinit = 0;
  uint16 addrreg0 = 0, addrreg1 = 0;
  uint8 dipswitch = 0;
  uint8 *WRAM = nullptr;

  virtual DECLFR_RET DefRead(DECLFR_ARGS) {
    return Cart::CartBROB(DECLFR_FORWARD);
  }
  virtual void WSync() {}

  void LatchWrite(DECLFW_ARGS) {
    latch = A;
    WSync();
  }

  void Reset() override {
    latch = latchinit;
    WSync();
  }

  void Power() override {
    latch = latchinit;
    WSync();
    if (WRAM) {
      fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
      fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    } else {
      fc->fceu->SetReadHandler(0x6000, 0xFFFF, [](DECLFR_ARGS) {
	  return ((AddrLatch*)fc->fceu->cartiface)->DefRead(DECLFR_FORWARD);
	});
    }
    fc->fceu->SetWriteHandler(addrreg0, addrreg1, [](DECLFW_ARGS) {
	((AddrLatch*)fc->fceu->cartiface)->LatchWrite(DECLFW_FORWARD);
      });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((AddrLatch*)fc->fceu->cartiface)->WSync();
  }

  // proc -> WSync, func -> DefRead
  AddrLatch(FC *fc, CartInfo *info, 
	    uint16 linit, uint16 adr0, uint16 adr1, uint8 wram) :
    CartInterface(fc) {
    latchinit = linit;
    addrreg0 = adr0;
    addrreg1 = adr1;

    if (wram) {
      WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
      fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
      if (info->battery) {
	info->SaveGame[0] = WRAM;
	info->SaveGameLen[0] = WRAMSIZE;
      }
      fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    }
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExState(&latch, 2, 0, "LATC");
  }
};
}

//------------------ UNLCC21 ---------------------------
namespace {
struct UNLCC21 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(latch & 1);
    fc->cart->setmirror(MI_0 + ((latch & 2) >> 1));
  }
};
}

CartInterface *UNLCC21_Init(FC *fc, CartInfo *info) {
  return new UNLCC21(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ BMCD1038 ---------------------------
namespace {
struct BMCD1038 : public AddrLatch {
  void WSync() override {
    if (latch & 0x80) {
      fc->cart->setprg16(0x8000, (latch & 0x70) >> 4);
      fc->cart->setprg16(0xC000, (latch & 0x70) >> 4);
    } else {
      fc->cart->setprg32(0x8000, (latch & 0x60) >> 5);
    }
    fc->cart->setchr8(latch & 7);
    fc->cart->setmirror(((latch & 8) >> 3) ^ 1);
  }

  DECLFR_RET DefRead(DECLFR_ARGS) override {
    if (latch & 0x100)
      return dipswitch;
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }

  void Reset() override {
    dipswitch++;
    dipswitch &= 3;
  }

  BMCD1038(FC *fc, CartInfo *info, 
	   uint16 linit, uint16 adr0, uint16 adr1, uint8 wram) :
    AddrLatch(fc, info, linit, adr0, adr1, wram) {
    fc->state->AddExState(&dipswitch, 1, 0, "DIPs");
  }
};
}

CartInterface *BMCD1038_Init(FC *fc, CartInfo *info) {
  return new BMCD1038(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ UNL43272 ---------------------------
// mapper much complex, including 16K bankswitching
namespace {
struct UNL43272 : public AddrLatch {
  void WSync() override {
    if ((latch & 0x81) == 0x81) {
      fc->cart->setprg32(0x8000, (latch & 0x38) >> 3);
    } else
      FCEU_printf("unrecognized command %04!\n", latch);
    fc->cart->setchr8(0);
    fc->cart->setmirror(0);
  }

  DECLFR_RET DefRead(DECLFR_ARGS) override {
    if (latch & 0x400)
      return Cart::CartBR(fc, A & 0xFE);
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }

  void Reset() override {
    latch = 0;
    WSync();
  }

  UNL43272(FC *fc, CartInfo *info, 
	   uint16 linit, uint16 adr0, uint16 adr1, uint8 wram) :
    AddrLatch(fc, info, linit, adr0, adr1, wram) {
    fc->state->AddExState(&dipswitch, 1, 0, "DIPs");
  }
};
}

CartInterface *UNL43272_Init(FC *fc, CartInfo *info) {
  return new UNL43272(fc, info, 0x0081, 0x8000, 0xFFFF, 0);
}

//------------------ Map 058 ---------------------------
namespace {
struct BMCGK192 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    if (latch & 0x40) {
      fc->cart->setprg16(0x8000, latch & 7);
      fc->cart->setprg16(0xC000, latch & 7);
    } else {
      fc->cart->setprg32(0x8000, (latch >> 1) & 3);
    }
    fc->cart->setchr8((latch >> 3) & 7);
    fc->cart->setmirror(((latch & 0x80) >> 7) ^ 1);
  }
};
}

CartInterface *BMCGK192_Init(FC *fc, CartInfo *info) {
  return new BMCGK192(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 059 ---------------------------
// One more forbidden mapper
namespace {
struct M59 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch >> 4) & 7);
    fc->cart->setchr8(latch & 0x7);
    fc->cart->setmirror((latch >> 3) & 1);
  }

  DECLFR_RET DefRead(DECLFR_ARGS) override {
    if (latch & 0x100)
      return 0;
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }
};
}

CartInterface *Mapper59_Init(FC *fc, CartInfo *info) {
  return new M59(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 092 ---------------------------
// Another two-in-one mapper, two Jaleco carts uses similar
// hardware, but with different wiring.
// Original code provided by LULU
// Additionally, PCB contains DSP extra sound chip, used for voice samples
// (unemulated)
namespace {
struct M92 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    uint8 reg = latch & 0xF0;
    fc->cart->setprg16(0x8000, 0);
    if (latch >= 0x9000) {
      switch (reg) {
      case 0xD0: fc->cart->setprg16(0xc000, latch & 15); break;
      case 0xE0: fc->cart->setchr8(latch & 15); break;
      }
    } else {
      switch (reg) {
      case 0xB0: fc->cart->setprg16(0xc000, latch & 15); break;
      case 0x70: fc->cart->setchr8(latch & 15); break;
      }
    }
  }
};
}

CartInterface *Mapper92_Init(FC* fc, CartInfo *info) {
  return new M92(fc, info, 0x80B0, 0x8000, 0xFFFF, 0);
}

//------------------ Map 200 ---------------------------
namespace {
struct M200 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, latch & 7);
    fc->cart->setprg16(0xC000, latch & 7);
    fc->cart->setchr8(latch & 7);
    fc->cart->setmirror((latch & 8) >> 3);
  }
};
}

CartInterface *Mapper200_Init(FC *fc, CartInfo *info) {
  return new M200(fc, info, 0xFFFF, 0x8000, 0xFFFF, 0);
}

//------------------ Map 201 ---------------------------
namespace {
struct M201 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    if (latch & 8) {
      fc->cart->setprg32(0x8000, latch & 3);
      fc->cart->setchr8(latch & 3);
    } else {
      fc->cart->setprg32(0x8000, 0);
      fc->cart->setchr8(0);
    }
  }
};
}

CartInterface *Mapper201_Init(FC *fc, CartInfo *info) {
  return new M201(fc, info, 0xFFFF, 0x8000, 0xFFFF, 0);
}

//------------------ Map 202 ---------------------------

namespace {
struct M202 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    // According to more careful hardware tests and PCB study
    int32 mirror = latch & 1;
    int32 bank = (latch >> 1) & 0x7;
    int32 select = (mirror & (bank >> 2));
    fc->cart->setprg16(0x8000, select ? (bank & 6) | 0 : bank);
    fc->cart->setprg16(0xc000, select ? (bank & 6) | 1 : bank);
    fc->cart->setmirror(mirror ^ 1);
    fc->cart->setchr8(bank);
  }
};
}

CartInterface *Mapper202_Init(FC *fc, CartInfo *info) {
  return new M202(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 204 ---------------------------
namespace {
struct M204 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    int32 tmp2 = latch & 0x6;
    int32 tmp1 = tmp2 + ((tmp2 == 0x6) ? 0 : (latch & 1));
    fc->cart->setprg16(0x8000, tmp1);
    fc->cart->setprg16(0xc000, tmp2 + ((tmp2 == 0x6) ? 1 : (latch & 1)));
    fc->cart->setchr8(tmp1);
    fc->cart->setmirror(((latch >> 4) & 1) ^ 1);
  }
};
}

CartInterface *Mapper204_Init(FC *fc, CartInfo *info) {
  return new M204(fc, info, 0xFFFF, 0x8000, 0xFFFF, 0);
}

//------------------ Map 212 ---------------------------
namespace {
struct M212 : public AddrLatch {
  using AddrLatch::AddrLatch;
  DECLFR_RET DefRead(DECLFR_ARGS) override {
    uint8 ret = Cart::CartBROB(DECLFR_FORWARD);
    if ((A & 0xE010) == 0x6000) ret |= 0x80;
    return ret;
  }

  void WSync() override {
    if (latch & 0x4000) {
      fc->cart->setprg32(0x8000, (latch >> 1) & 3);
    } else {
      fc->cart->setprg16(0x8000, latch & 7);
      fc->cart->setprg16(0xC000, latch & 7);
    }
    fc->cart->setchr8(latch & 7);
    fc->cart->setmirror(((latch >> 3) & 1) ^ 1);
  }
};
}

CartInterface *Mapper212_Init(FC *fc, CartInfo *info) {
  return new M212(fc, info, 0xFFFF, 0x8000, 0xFFFF, 0);
}

//------------------ Map 213 ---------------------------
namespace {
struct M213 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch >> 1) & 3);
    fc->cart->setchr8((latch >> 3) & 7);
  }
};
}

CartInterface *Mapper213_Init(FC *fc, CartInfo *info) {
  return new M213(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 214 ---------------------------
namespace {
struct M214 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, (latch >> 2) & 3);
    fc->cart->setprg16(0xC000, (latch >> 2) & 3);
    fc->cart->setchr8(latch & 3);
  }
};
}

CartInterface *Mapper214_Init(FC *fc, CartInfo *info) {
  return new M214(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 217 ---------------------------
namespace {
struct M217 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch >> 2) & 3);
    fc->cart->setchr8(latch & 7);
  }
};
}

CartInterface *Mapper217_Init(FC *fc, CartInfo *info) {
  return new M217(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 227 ---------------------------

namespace {
struct M227 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    uint32 S = latch & 1;
    uint32 p = ((latch >> 2) & 0x1F) + ((latch & 0x100) >> 3);
    uint32 L = (latch >> 9) & 1;

    if ((latch >> 7) & 1) {
      if (S) {
	fc->cart->setprg32(0x8000, p >> 1);
      } else {
	fc->cart->setprg16(0x8000, p);
	fc->cart->setprg16(0xC000, p);
      }
    } else {
      if (S) {
	if (L) {
	  fc->cart->setprg16(0x8000, p & 0x3E);
	  fc->cart->setprg16(0xC000, p | 7);
	} else {
	  fc->cart->setprg16(0x8000, p & 0x3E);
	  fc->cart->setprg16(0xC000, p & 0x38);
	}
      } else {
	if (L) {
	  fc->cart->setprg16(0x8000, p);
	  fc->cart->setprg16(0xC000, p | 7);
	} else {
	  fc->cart->setprg16(0x8000, p);
	  fc->cart->setprg16(0xC000, p & 0x38);
	}
      }
    }

    fc->cart->setmirror(((latch >> 1) & 1) ^ 1);
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
  }
};
}

CartInterface *Mapper227_Init(FC *fc, CartInfo *info) {
  return new M227(fc, info, 0x0000, 0x8000, 0xFFFF, 1);
}

//------------------ Map 229 ---------------------------
namespace {
struct M229 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setchr8(latch);
    if (!(latch & 0x1e)) {
      fc->cart->setprg32(0x8000, 0);
    } else {
      fc->cart->setprg16(0x8000, latch & 0x1F);
      fc->cart->setprg16(0xC000, latch & 0x1F);
    }
    fc->cart->setmirror(((latch >> 5) & 1) ^ 1);
  }
};
}

CartInterface *Mapper229_Init(FC *fc, CartInfo *info) {
  return new M229(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 231 ---------------------------
namespace {
struct M231 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setchr8(0);
    if (latch & 0x20) {
      fc->cart->setprg32(0x8000, (latch >> 1) & 0x0F);
    } else {
      fc->cart->setprg16(0x8000, latch & 0x1E);
      fc->cart->setprg16(0xC000, latch & 0x1E);
    }
    fc->cart->setmirror(((latch >> 7) & 1) ^ 1);
  }
};
}

CartInterface *Mapper231_Init(FC *fc, CartInfo *info) {
  return new M231(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 242 ---------------------------
namespace {
struct M242 : public AddrLatch {
  using AddrLatch::AddrLatch;

  void WSync() override {
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, (latch >> 3) & 0xf);
    fc->cart->setmirror(((latch >> 1) & 1) ^ 1);
  }
};
}

CartInterface *Mapper242_Init(FC *fc, CartInfo *info) {
  return new M242(fc, info, 0x0000, 0x8000, 0xFFFF, 1);
}

//------------------ 190in1 ---------------------------

namespace {
struct BMC190 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    fc->cart->setprg16(0x8000, (latch >> 2) & 7);
    fc->cart->setprg16(0xC000, (latch >> 2) & 7);
    fc->cart->setchr8((latch >> 2) & 7);
    fc->cart->setmirror((latch & 1) ^ 1);
  }
};
}

CartInterface *BMC190in1_Init(FC *fc, CartInfo *info) {
  return new BMC190(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//-------------- BMC810544-C-A1 ------------------------

namespace {
struct BMC810544 : public AddrLatch {
  using AddrLatch::AddrLatch;
  void WSync() override {
    uint32 bank = latch >> 7;
    if (latch & 0x40) {
      fc->cart->setprg32(0x8000, bank);
    } else {
      fc->cart->setprg16(0x8000, (bank << 1) | ((latch >> 5) & 1));
      fc->cart->setprg16(0xC000, (bank << 1) | ((latch >> 5) & 1));
    }
    fc->cart->setchr8(latch & 0x0f);
    fc->cart->setmirror(((latch >> 4) & 1) ^ 1);
  }
};
}

CartInterface *BMC810544CA1_Init(FC *fc, CartInfo *info) {
  return new BMC810544(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//-------------- BMCNTD-03 ------------------------
namespace {
struct BMCNTD : public AddrLatch {
  using AddrLatch::AddrLatch;

  void WSync() override {
    // 1PPP Pmcc spxx xccc
    // 1000 0000 0000 0000 v
    // 1001 1100 0000 0100 h
    // 1011 1010 1100 0100
    uint32 prg = ((latch >> 10) & 0x1e);
    uint32 chr = ((latch & 0x0300) >> 5) | (latch & 7);
    if (latch & 0x80) {
      fc->cart->setprg16(0x8000, prg | ((latch >> 6) & 1));
      fc->cart->setprg16(0xC000, prg | ((latch >> 6) & 1));
    } else {
      fc->cart->setprg32(0x8000, prg >> 1);
    }
    fc->cart->setchr8(chr);
    fc->cart->setmirror(((latch >> 10) & 1) ^ 1);
  }
};
}

CartInterface *BMCNTD03_Init(FC *fc, CartInfo *info) {
  return new BMCNTD(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

//-------------- BMCG-146 ------------------------

namespace {
struct BMCG146 : public AddrLatch {
  using AddrLatch::AddrLatch;

  void WSync() override {
    fc->cart->setchr8(0);
    if (latch & 0x800) {  // UNROM mode
      fc->cart->setprg16(0x8000,
			 (latch & 0x1F) | (latch & ((latch & 0x40) >> 6)));
      fc->cart->setprg16(0xC000, (latch & 0x18) | 7);
    } else {
      if (latch & 0x40) {  // 16K mode
	fc->cart->setprg16(0x8000, latch & 0x1F);
	fc->cart->setprg16(0xC000, latch & 0x1F);
      } else {
	fc->cart->setprg32(0x8000, (latch >> 1) & 0x0F);
      }
    }
    fc->cart->setmirror(((latch & 0x80) >> 7) ^ 1);
  }
};
}

CartInterface *BMCG146_Init(FC *fc, CartInfo *info) {
  return new BMCG146(fc, info, 0x0000, 0x8000, 0xFFFF, 0);
}

