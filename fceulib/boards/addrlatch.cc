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

#if 0

//------------------ Map 202 ---------------------------

static void M202Sync() {
  // According to more carefull hardware tests and PCB study
  int32 mirror = latch & 1;
  int32 bank = (latch >> 1) & 0x7;
  int32 select = (mirror & (bank >> 2));
  fc->cart->setprg16(0x8000, select ? (bank & 6) | 0 : bank);
  fc->cart->setprg16(0xc000, select ? (bank & 6) | 1 : bank);
  fc->cart->setmirror(mirror ^ 1);
  fc->cart->setchr8(bank);
}

void Mapper202_Init(CartInfo *info) {
  Latch_Init(info, M202Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 204 ---------------------------

static void M204Sync() {
  int32 tmp2 = latch & 0x6;
  int32 tmp1 = tmp2 + ((tmp2 == 0x6) ? 0 : (latch & 1));
  fc->cart->setprg16(0x8000, tmp1);
  fc->cart->setprg16(0xc000, tmp2 + ((tmp2 == 0x6) ? 1 : (latch & 1)));
  fc->cart->setchr8(tmp1);
  fc->cart->setmirror(((latch >> 4) & 1) ^ 1);
}

void Mapper204_Init(CartInfo *info) {
  Latch_Init(info, M204Sync, nullptr, 0xFFFF, 0x8000, 0xFFFF, 0);
}

//------------------ Map 212 ---------------------------

static DECLFR(M212Read) {
  uint8 ret = Cart::CartBROB(DECLFR_FORWARD);
  if ((A & 0xE010) == 0x6000) ret |= 0x80;
  return ret;
}

static void M212Sync() {
  if (latch & 0x4000) {
    fc->cart->setprg32(0x8000, (latch >> 1) & 3);
  } else {
    fc->cart->setprg16(0x8000, latch & 7);
    fc->cart->setprg16(0xC000, latch & 7);
  }
  fc->cart->setchr8(latch & 7);
  fc->cart->setmirror(((latch >> 3) & 1) ^ 1);
}

void Mapper212_Init(CartInfo *info) {
  Latch_Init(info, M212Sync, M212Read, 0xFFFF, 0x8000, 0xFFFF, 0);
}

//------------------ Map 213 ---------------------------

static void M213Sync() {
  fc->cart->setprg32(0x8000, (latch >> 1) & 3);
  fc->cart->setchr8((latch >> 3) & 7);
}

void Mapper213_Init(CartInfo *info) {
  Latch_Init(info, M213Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 214 ---------------------------

static void M214Sync() {
  fc->cart->setprg16(0x8000, (latch >> 2) & 3);
  fc->cart->setprg16(0xC000, (latch >> 2) & 3);
  fc->cart->setchr8(latch & 3);
}

void Mapper214_Init(CartInfo *info) {
  Latch_Init(info, M214Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 217 ---------------------------

static void M217Sync() {
  fc->cart->setprg32(0x8000, (latch >> 2) & 3);
  fc->cart->setchr8(latch & 7);
}

void Mapper217_Init(CartInfo *info) {
  Latch_Init(info, M217Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 227 ---------------------------

static void M227Sync() {
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

void Mapper227_Init(CartInfo *info) {
  Latch_Init(info, M227Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 1);
}

//------------------ Map 229 ---------------------------

static void M229Sync() {
  fc->cart->setchr8(latch);
  if (!(latch & 0x1e)) {
    fc->cart->setprg32(0x8000, 0);
  } else {
    fc->cart->setprg16(0x8000, latch & 0x1F);
    fc->cart->setprg16(0xC000, latch & 0x1F);
  }
  fc->cart->setmirror(((latch >> 5) & 1) ^ 1);
}

void Mapper229_Init(CartInfo *info) {
  Latch_Init(info, M229Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 231 ---------------------------

static void M231Sync() {
  fc->cart->setchr8(0);
  if (latch & 0x20) {
    fc->cart->setprg32(0x8000, (latch >> 1) & 0x0F);
  } else {
    fc->cart->setprg16(0x8000, latch & 0x1E);
    fc->cart->setprg16(0xC000, latch & 0x1E);
  }
  fc->cart->setmirror(((latch >> 7) & 1) ^ 1);
}

void Mapper231_Init(CartInfo *info) {
  Latch_Init(info, M231Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//------------------ Map 242 ---------------------------

static void M242Sync() {
  fc->cart->setchr8(0);
  fc->cart->setprg8r(0x10, 0x6000, 0);
  fc->cart->setprg32(0x8000, (latch >> 3) & 0xf);
  fc->cart->setmirror(((latch >> 1) & 1) ^ 1);
}

void Mapper242_Init(CartInfo *info) {
  Latch_Init(info, M242Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 1);
}

//------------------ 190in1 ---------------------------

static void BMC190in1Sync() {
  fc->cart->setprg16(0x8000, (latch >> 2) & 7);
  fc->cart->setprg16(0xC000, (latch >> 2) & 7);
  fc->cart->setchr8((latch >> 2) & 7);
  fc->cart->setmirror((latch & 1) ^ 1);
}

void BMC190in1_Init(CartInfo *info) {
  Latch_Init(info, BMC190in1Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//-------------- BMC810544-C-A1 ------------------------

static void BMC810544CA1Sync() {
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

void BMC810544CA1_Init(CartInfo *info) {
  Latch_Init(info, BMC810544CA1Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//-------------- BMCNTD-03 ------------------------

static void BMCNTD03Sync() {
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

void BMCNTD03_Init(CartInfo *info) {
  Latch_Init(info, BMCNTD03Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}

//-------------- BMCG-146 ------------------------

static void BMCG146Sync() {
  fc->cart->setchr8(0);
  if (latch & 0x800) {  // UNROM mode
    fc->cart->setprg16(
        0x8000, (latch & 0x1F) | (latch & ((latch & 0x40) >> 6)));
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

void BMCG146_Init(CartInfo *info) {
  Latch_Init(info, BMCG146Sync, nullptr, 0x0000, 0x8000, 0xFFFF, 0);
}
#endif
