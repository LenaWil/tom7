/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO
 *  Copyright (C) 2003 Xodnizel
 *  Mapper 12 code Copyright (C) 2003 CaH4e3
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

/*  Code for emulating iNES mappers 4,12,44,45,47,49,52,74,114,115,116,118,
    119,165,205,245,249,250,254
*/

#include "mapinc.h"
#include "mmc3.h"

#include "tracing.h"

// ----------------------------------------------------------------------
// ------------------------- Generic MM3 Code ---------------------------
// ----------------------------------------------------------------------

void MMC3::FixMMC3PRG(int V) {
  if (V & 0x40) {
    PWrap(0xC000, DRegBuf[6]);
    PWrap(0x8000, ~1);
  } else {
    PWrap(0x8000, DRegBuf[6]);
    PWrap(0xC000, ~1);
  }
  PWrap(0xA000, DRegBuf[7]);
  PWrap(0xE000, ~0);
}

void MMC3::FixMMC3CHR(int V) {
  int cbase = (V & 0x80) << 5;

  CWrap((cbase ^ 0x000), DRegBuf[0] & (~1));
  CWrap((cbase ^ 0x400), DRegBuf[0] | 1);
  CWrap((cbase ^ 0x800), DRegBuf[1] & (~1));
  CWrap((cbase ^ 0xC00), DRegBuf[1] | 1);

  CWrap(cbase ^ 0x1000, DRegBuf[2]);
  CWrap(cbase ^ 0x1400, DRegBuf[3]);
  CWrap(cbase ^ 0x1800, DRegBuf[4]);
  CWrap(cbase ^ 0x1c00, DRegBuf[5]);

  MWrap(A000B);
}

// Was MMC3RegReset.
void MMC3::Reset() {
  irq_count = irq_latch = irq_a = MMC3_cmd = 0;

  DRegBuf[0] = 0;
  DRegBuf[1] = 2;
  DRegBuf[2] = 4;
  DRegBuf[3] = 5;
  DRegBuf[4] = 6;
  DRegBuf[5] = 7;
  DRegBuf[6] = 0;
  DRegBuf[7] = 1;

  FixMMC3PRG(0);
  FixMMC3CHR(0);
}

// static
DECLFW_RET MMC3::MMC3_CMDWrite(DECLFW_ARGS) {
  ((MMC3 *)fc->fceu->cartiface)->MMC3_CMDWrite_Direct(DECLFW_FORWARD);
}

DECLFW_RET MMC3::MMC3_CMDWrite_Direct(DECLFW_ARGS) {
  // FCEU_printf("bs %04x %02x\n",A,V);
  switch (A & 0xE001) {
    case 0x8000:
      if ((V & 0x40) != (MMC3_cmd & 0x40)) FixMMC3PRG(V);
      if ((V & 0x80) != (MMC3_cmd & 0x80)) FixMMC3CHR(V);
      MMC3_cmd = V;
      break;
    case 0x8001: {
      int cbase = (MMC3_cmd & 0x80) << 5;
      DRegBuf[MMC3_cmd & 0x7] = V;
      switch (MMC3_cmd & 0x07) {
        case 0:
          CWrap((cbase ^ 0x000), V & (~1));
          CWrap((cbase ^ 0x400), V | 1);
          break;
        case 1:
          CWrap((cbase ^ 0x800), V & (~1));
          CWrap((cbase ^ 0xC00), V | 1);
          break;
        case 2: CWrap(cbase ^ 0x1000, V); break;
        case 3: CWrap(cbase ^ 0x1400, V); break;
        case 4: CWrap(cbase ^ 0x1800, V); break;
        case 5: CWrap(cbase ^ 0x1C00, V); break;
        case 6:
          if (MMC3_cmd & 0x40)
            PWrap(0xC000, V);
          else
            PWrap(0x8000, V);
          break;
        case 7: PWrap(0xA000, V); break;
      }
      break;
    }
    case 0xA000:
      MWrap(V);
      break;
    case 0xA001: A001B = V; break;
  }
}

// static
DECLFW_RET MMC3::MMC3_IRQWrite(DECLFW_ARGS) {
  ((MMC3 *)fc->fceu->cartiface)->MMC3_IRQWrite_Direct(DECLFW_FORWARD);
}

DECLFW_RET MMC3::MMC3_IRQWrite_Direct(DECLFW_ARGS) {
  // FCEU_printf("%04x:%04x\n",A,V);
  switch (A & 0xE001) {
    case 0xC000: irq_latch = V; break;
    case 0xC001: irq_reload = 1; break;
    case 0xE000:
      fc->X->IRQEnd(FCEU_IQEXT);
      irq_a = 0;
      break;
    case 0xE001: irq_a = 1; break;
  }
}

void MMC3::ClockMMC3Counter() {
  int count = irq_count;
  if (!count || irq_reload) {
    irq_count = irq_latch;
    irq_reload = 0;
  } else {
    irq_count--;
  }
  if ((count | isRevB) && !irq_count) {
    if (irq_a) {
      fc->X->IRQBegin(FCEU_IQEXT);
    }
  }
}

void MMC3::GenMMC3Restore(FC *fc, int version) {
  FixMMC3PRG(MMC3_cmd);
  FixMMC3CHR(MMC3_cmd);
}

void MMC3::CWrap(uint32 A, uint8 V) {
  // Business Wars NEEDS THIS for 8K CHR-RAM
  fc->cart->setchr1(A, V);
}

void MMC3::PWrap(uint32 A, uint8 V) {
  // [NJ102] Mo Dao Jie (C) has 1024Mb
  // MMC3 BOARD, maybe something other
  // will be broken
  fc->cart->setprg8(A, V & 0x7F);  
}

void MMC3::MWrap(uint8 V) {
  A000B = V;
  fc->cart->setmirror((V & 1) ^ 1);
}

// static
DECLFR_RET MMC3::MAWRAMMMC6(DECLFR_ARGS) {
  return MMC3_WRAM[A & 0x3ff];
}

// static
void MMC3::MBWRAMMMC6(DECLFW_ARGS) {
  MMC3_WRAM[A & 0x3ff] = V;
}

// Was GenMM3CPower
void MMC3::Power() {
  if (fc->unif->UNIFchrrama) fc->cart->setchr8(0);

  fc->fceu->SetWriteHandler(0x8000, 0xBFFF, MMC3_CMDWrite);
  fc->fceu->SetWriteHandler(0xC000, 0xFFFF, MMC3_IRQWrite);
  fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  A001B = A000B = 0;
  fc->cart->setmirror(1);
  if (mmc3opts & 1) {
    if (wrams == 1024) {
      // FCEU_CheatAddRAM(1,0x7000,MMC3_WRAM);
      fc->fceu->SetReadHandler(0x7000, 0x7FFF,
			       [](DECLFR_ARGS) -> DECLFR_RET {
				 return ((MMC3 *)fc->fceu->cartiface)->
				   MAWRAMMMC6(DECLFR_FORWARD);
			       });
      fc->fceu->SetWriteHandler(0x7000, 0x7FFF,
				[](DECLFW_ARGS) {
				  ((MMC3 *)fc->fceu->cartiface)->
				    MBWRAMMMC6(DECLFW_FORWARD);
				});
    } else {
      // FCEU_CheatAddRAM((wrams&0x1fff)>>10,0x6000,MMC3_WRAM);
      fc->fceu->SetWriteHandler(0x6000, 0x6000 + ((wrams - 1) & 0x1fff),
				Cart::CartBW);
      fc->fceu->SetReadHandler(0x6000, 0x6000 + ((wrams - 1) & 0x1fff),
			       Cart::CartBR);
      fc->cart->setprg8r(0x10, 0x6000, 0);
    }
    if (!(mmc3opts & 2)) FCEU_dwmemset(MMC3_WRAM, 0, wrams);
  }
  Reset();
  if (CHRRAM) FCEU_dwmemset(CHRRAM, 0, CHRRAMSize);
}


// was GenMMC3Close
void MMC3::Close() {
  free(CHRRAM);
  free(MMC3_WRAM);
  CHRRAM = MMC3_WRAM = nullptr;
}

// was GenMMC3_Init
MMC3::MMC3(FC *fc, CartInfo *info, int prg, int chr, int wram, int battery)
  : CartInterface(fc) {

  // PERF probably don't need to keep it around
  MMC3_StateRegs = {
    {DRegBuf, 8, "REGS"}, {&MMC3_cmd, 1, "CMD0"}, {&A000B, 1, "A000"},
    {&A001B, 1, "A001"}, {&irq_reload, 1, "IRQR"}, {&irq_count, 1, "IRQC"},
    {&irq_latch, 1, "IRQL"}, {&irq_a, 1, "IRQA"}
  };

  wrams = wram << 10;

  fc->cart->PRGmask8[0] &= (prg >> 13) - 1;
  fc->cart->CHRmask1[0] &= (chr >> 10) - 1;
  fc->cart->CHRmask2[0] &= (chr >> 11) - 1;

  if (wram) {
    mmc3opts |= 1;
    MMC3_WRAM = (uint8 *)FCEU_gmalloc(wrams);
    TRACEF("MMC3 Init %d %d %d %d", prg, chr, wram, battery);
    fc->cart->SetupCartPRGMapping(0x10, MMC3_WRAM, wrams, 1);
    fc->state->AddExState(MMC3_WRAM, wrams, 0, "MRAM");

    TRACEA(DRegBuf, 8);
    TRACEN(MMC3_cmd);
    TRACEN(A000B);
    TRACEN(A001B);
    TRACEN(irq_reload);
    TRACEN(irq_count);
    TRACEN(irq_latch);
    TRACEN(irq_a);
  }

  if (battery) {
    TRACEF("Adding savegame");
    mmc3opts |= 2;
    info->SaveGame[0] = MMC3_WRAM;
    info->SaveGameLen[0] = wrams;
  }

  fc->state->AddExVec(MMC3_StateRegs);

  if (info->CRC32 == 0x5104833e) {
    // Kick Master
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      MMC3 *me = (MMC3 *)fc->fceu->cartiface;
      if (fc->ppu->scanline == 238) me->ClockMMC3Counter();
      me->ClockMMC3Counter();
    };

  } else if (info->CRC32 == 0x5a6860f1 || info->CRC32 == 0xae280e20) {
    // Shougi Meikan '92/'93
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      MMC3 *me = (MMC3 *)fc->fceu->cartiface;
      if (fc->ppu->scanline == 238) me->ClockMMC3Counter();
      me->ClockMMC3Counter();
    };
    
  } else if (info->CRC32 == 0xfcd772eb) {
    // PAL Star Wars, similar problem as Kick Master.
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      MMC3 *me = (MMC3 *)fc->fceu->cartiface;
      if (fc->ppu->scanline == 240) me->ClockMMC3Counter();
      me->ClockMMC3Counter();
    };

  } else {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      MMC3 *me = (MMC3 *)fc->fceu->cartiface;
      me->ClockMMC3Counter();
    };
  }

  fc->fceu->GameStateRestore = [](FC *fc, int version) {
    MMC3 *me = (MMC3 *)fc->fceu->cartiface;
    me->GenMMC3Restore(fc, version);
  };
  
  TRACEF("MMC3_WRAM is %d...", wrams);
  TRACEA(MMC3_WRAM, wrams);
}

// ----------------------------------------------------------------------
// -------------------------- MMC3 Based Code ---------------------------
// ----------------------------------------------------------------------

// ---------------------------- Mapper 4 --------------------------------

namespace {
struct Mapper4 : public MMC3 {
  /* For Karnov, maybe others.  BLAH.  Stupid iNES format.*/
  int hackm4 = 0;

  void Power() override {
    TRACEF("M4power %d...", hackm4);
    MMC3::Power();
    A000B = (hackm4 ^ 1) & 1;
    fc->cart->setmirror(hackm4);
  }

  Mapper4(FC *fc, CartInfo *info, int ws) :
    MMC3(fc, info, 512, 256, ws, info->battery) {
    hackm4 = info->mirror;
  }
};
}

CartInterface *Mapper4_Init(FC *fc, CartInfo *info) {
  int ws = 8;

  if ((info->CRC32 == 0x93991433 || info->CRC32 == 0xaf65aa84)) {
    FCEU_printf(
        "Low-G-Man can not work normally in the iNES format.\n"
        "This game has been recognized by its CRC32 value, and\n"
        "the appropriate changes will be made so it will run.\n"
        "If you wish to hack this game, you should use the UNIF\n"
        "format for your hack.\n\n");
    ws = 0;
  }
  return new Mapper4(fc, info, ws);
}

// ---------------------------- Mapper 12 -------------------------------

namespace {
struct Mapper12 : public MMC3 {
  // PERF can probably be 2? -tom7
  uint8 EXPREGS[8] = {};
  
  void M12Write(DECLFW_ARGS) {
    EXPREGS[0] = V & 0x01;
    EXPREGS[1] = (V & 0x10) >> 4;
  }

  void Power() override {
    EXPREGS[0] = EXPREGS[1] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x4100, 0x5FFF, [](DECLFW_ARGS) {
      ((Mapper12 *)fc->fceu->cartiface)->M12Write(DECLFW_FORWARD);
    });
  }

  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1(A, (EXPREGS[(A & 0x1000) >> 12] << 8) + V);
  }

  Mapper12(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 2, 0, "EXPR");
    isRevB = 0;
  }
};
}

CartInterface *Mapper12_Init(FC *fc, CartInfo *info) {
  return new Mapper12(fc, info);
}

// ---------------------------- Mapper 37 -------------------------------

namespace {
struct Mapper37 : public MMC3 {
  // PERF 1? Just value?
  uint8 EXPREGS[8] = {};
  
  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] != 2)
      V &= 0x7;
    else
      V &= 0xF;
    V |= EXPREGS[0] << 3;
    fc->cart->setprg8(A, V);
  }

  void CWrap(uint32 A, uint8 V) override {
    uint32 NV = V;
    NV &= 0x7F;
    NV |= EXPREGS[0] << 6;
    fc->cart->setchr1(A, NV);
  }

  void M37Write(DECLFW_ARGS) {
    EXPREGS[0] = (V & 6) >> 1;
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Reset() override {
    EXPREGS[0] = 0;
    MMC3::Reset();
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      ((Mapper37*)fc->fceu->cartiface)->M37Write(DECLFW_FORWARD);
    });
  }

  Mapper37(FC *fc, CartInfo *info) :
    MMC3(fc, info, 512, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");    
  }
};
}

CartInterface *Mapper37_Init(FC *fc, CartInfo *info) {
  return new Mapper37(fc, info);
}

// ---------------------------- Mapper 44 -------------------------------

namespace {
struct Mapper44 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    uint32 NV = V;
    if (EXPREGS[0] >= 6)
      NV &= 0x1F;
    else
      NV &= 0x0F;
    NV |= EXPREGS[0] << 4;
    fc->cart->setprg8(A, NV);
  }

  void CWrap(uint32 A, uint8 V) override {
    uint32 NV = V;
    if (EXPREGS[0] < 6) NV &= 0x7F;
    NV |= EXPREGS[0] << 7;
    fc->cart->setchr1(A, NV);
  }

  void M44Write(DECLFW_ARGS) {
    if (A & 1) {
      EXPREGS[0] = V & 7;
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
    } else {
      MMC3_CMDWrite_Direct(DECLFW_FORWARD);
    }
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0xA000, 0xBFFF, [](DECLFW_ARGS) {
      ((Mapper44*)fc->fceu->cartiface)->M44Write(DECLFW_FORWARD);
    });
  }

  Mapper44(FC *fc, CartInfo *info) :
    MMC3(fc, info, 512, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
  }
};
}

CartInterface *Mapper44_Init(FC *fc, CartInfo *info) {
  return new Mapper44(fc, info);
}

// ---------------------------- Mapper 45 -------------------------------

struct Mapper45 : public MMC3 {
  uint8 EXPREGS[8] = {};

  void CWrap(uint32 A, uint8 V) override {
    if (!fc->unif->UNIFchrrama) {
      uint32 NV = V;
      if (EXPREGS[2] & 8)
	NV &= (1 << ((EXPREGS[2] & 7) + 1)) - 1;
      else if (EXPREGS[2])
	NV &= 0;  // hack ;( don't know exactly how it should be
      NV |= EXPREGS[0] | ((EXPREGS[2] & 0xF0) << 4);
      fc->cart->setchr1(A, NV);
    }
  }

  void PWrap(uint32 A, uint8 V) override {
    V &= (EXPREGS[3] & 0x3F) ^ 0x3F;
    V |= EXPREGS[1];
    fc->cart->setprg8(A, V);
  }

  void M45_Write(DECLFW_ARGS) {
    if (EXPREGS[3] & 0x40) {
      MMC3_WRAM[A - 0x6000] = V;
      return;
    }
    EXPREGS[EXPREGS[4]] = V;
    EXPREGS[4] = (EXPREGS[4] + 1) & 3;
    // if (!EXPREGS[4])
    // {
    //   FCEU_printf("CHROR %02x, PRGOR %02x, CHRAND %02x, PRGAND
    //   %02x\n",EXPREGS[0],EXPREGS[1],EXPREGS[2],EXPREGS[3]);
    //   FCEU_printf("CHR0 %03x, CHR1 %03x, PRG0 %03x, PRG1 %03x\n",
    //               (0x00&((1<<((EXPREGS[2]&7)+1))-1))|(EXPREGS[0]|((EXPREGS[2]&0xF0)<<4)),
    //               (0xFF&((1<<((EXPREGS[2]&7)+1))-1))|(EXPREGS[0]|((EXPREGS[2]&0xF0)<<4)),
    //               (0x00&((EXPREGS[3]&0x3F)^0x3F))|(EXPREGS[1]),
    //               (0xFF&((EXPREGS[3]&0x3F)^0x3F))|(EXPREGS[1]));
    // }
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  DECLFR_RET M45_Read(DECLFR_ARGS) {
    uint32 addr = 1 << (EXPREGS[5] + 4);
    if (A & (addr | (addr - 1)))
      return fc->X->DB | 1;
    else
      return fc->X->DB;
  }

  void Reset() override {
    EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = EXPREGS[3] = EXPREGS[4] = 0;
    EXPREGS[5]++;
    EXPREGS[5] &= 7;
    MMC3::Reset();
  }

  void Power() override {
    fc->cart->setchr8(0);
    MMC3::Power();
    EXPREGS[0] = EXPREGS[1] = EXPREGS[2] =
      EXPREGS[3] = EXPREGS[4] = EXPREGS[5] =
      0;
    fc->fceu->SetWriteHandler(0x5000, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper45*)fc->fceu->cartiface)->M45_Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x5000, 0x5FFF, [](DECLFR_ARGS) {
      return ((Mapper45*)fc->fceu->cartiface)->M45_Read(DECLFR_FORWARD);
    });
  }

  Mapper45(FC *fc, CartInfo *info) :
    MMC3(fc, info, 512, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 5, 0, "EXPR");
  }
};

CartInterface *Mapper45_Init(FC *fc, CartInfo *info) {
  return new Mapper45(fc, info);
}

// ---------------------------- Mapper 47 -------------------------------

struct Mapper47 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    V &= 0xF;
    V |= EXPREGS[0] << 4;
    fc->cart->setprg8(A, V);
  }

  void CWrap(uint32 A, uint8 V) override {
    uint32 NV = V;
    NV &= 0x7F;
    NV |= EXPREGS[0] << 7;
    fc->cart->setchr1(A, NV);
  }

  void M47Write(DECLFW_ARGS) {
    EXPREGS[0] = V & 1;
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper47*)fc->fceu->cartiface)->M47Write(DECLFW_FORWARD);
    });
    // fc->fceu->SetReadHandler(0x6000,0x7FFF,0);
  }

  Mapper47(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, 0) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
  }
};

CartInterface *Mapper47_Init(FC *fc, CartInfo *info) {
  return new Mapper47(fc, info);
}

// ---------------------------- Mapper 49 -------------------------------

struct Mapper49 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 1) {
      V &= 0xF;
      V |= (EXPREGS[0] & 0xC0) >> 2;
      fc->cart->setprg8(A, V);
    } else {
      fc->cart->setprg32(0x8000, (EXPREGS[0] >> 4) & 3);
    }
  }

  void CWrap(uint32 A, uint8 V) override {
    uint32 NV = V;
    NV &= 0x7F;
    NV |= (EXPREGS[0] & 0xC0) << 1;
    fc->cart->setchr1(A, NV);
  }

  void M49Write(DECLFW_ARGS) {
    if (A001B & 0x80) {
      EXPREGS[0] = V;
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
    }
  }

  void Reset() override {
    EXPREGS[0] = 0;
    MMC3::Reset();
  }

  void Power() override {
    Reset();
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper49*)fc->fceu->cartiface)->M49Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, nullptr);
  }
  
 Mapper49(FC *fc, CartInfo *info)
   : MMC3(fc, info, 512, 256, 0, 0) {
   fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
 }
};

CartInterface *Mapper49_Init(FC *fc, CartInfo *info) {
   return new Mapper49(fc, info);
}

// ---------------------------- Mapper 52 -------------------------------

struct Mapper52 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    uint32 mask = 0x1F ^ ((EXPREGS[0] & 8) << 1);
    uint32 bank =
      ((EXPREGS[0] & 6) | ((EXPREGS[0] >> 3) & EXPREGS[0] & 1)) << 4;
    fc->cart->setprg8(A, bank | (V & mask));
  }

  void CWrap(uint32 A, uint8 V) override {
    uint32 mask = 0xFF ^ ((EXPREGS[0] & 0x40) << 1);
    // uint32 bank =
    // (((EXPREGS[0]>>3)&4)|((EXPREGS[0]>>1)&2)|
    // ((EXPREGS[0]>>6)&(EXPREGS[0]>>4)&1))<<7;
    uint32 bank = (((EXPREGS[0] >> 4) & 2) | (EXPREGS[0] & 4) |
		   ((EXPREGS[0] >> 6) & (EXPREGS[0] >> 4) & 1))
		  << 7;  // actually 256K CHR banks index bits is inverted!
    fc->cart->setchr1(A, bank | (V & mask));
  }

  void M52Write(DECLFW_ARGS) {
    if (EXPREGS[1]) {
      MMC3_WRAM[A - 0x6000] = V;
      return;
    }
    EXPREGS[1] = V & 0x80;
    EXPREGS[0] = V;
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Reset() override {
    EXPREGS[0] = EXPREGS[1] = 0;
    MMC3::Reset();
  }

  void Power() override {
    Reset();
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper52*)fc->fceu->cartiface)->M52Write(DECLFW_FORWARD);
    });
  }

  Mapper52(FC *fc, CartInfo *info)
    : MMC3(fc, info, 256, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 2, 0, "EXPR");
  }
};

CartInterface *Mapper52_Init(FC *fc, CartInfo *info) {
  return new Mapper52(fc, info);
}

// ---------------------------- Mapper 74 -------------------------------

struct Mapper74 : public MMC3 {
  void CWrap(uint32 A, uint8 V) override {
    if ((V == 8) || (V == 9)) {
      // Di 4 Ci - Ji Qi Ren Dai Zhan (As).nes, Ji Jia Zhan Shi (As).nes
      fc->cart->setchr1r(0x10, A, V);
    } else {
      fc->cart->setchr1r(0, A, V);
    }
  }

  Mapper74(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    CHRRAMSize = 2048;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");
  }
};
CartInterface *Mapper74_Init(FC *fc, CartInfo *info) {
  return new Mapper74(fc, info);
}

// ---------------------------- Mapper 114 ------------------------------
static constexpr uint8 m114_perm[8] = {0, 3, 1, 5, 6, 7, 2, 4};
struct Mapper114 : public MMC3 {
  uint8 cmdin = 0;
  uint8 EXPREGS[8] = {};

  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x80) {
      fc->cart->setprg16(0x8000, EXPREGS[0] & 0xF);
      fc->cart->setprg16(0xC000, EXPREGS[0] & 0xF);
    } else {
      fc->cart->setprg8(A, V & 0x3F);
    }
  }

  void M114Write(DECLFW_ARGS) {
    switch (A & 0xE001) {
      case 0x8001: MMC3_CMDWrite_Direct(fc, 0xA000, V); break;
      case 0xA000:
	MMC3_CMDWrite_Direct(fc, 0x8000, (V & 0xC0) | (m114_perm[V & 7]));
	cmdin = 1;
	break;
      case 0xC000:
	if (!cmdin) break;
	MMC3_CMDWrite_Direct(fc, 0x8001, V);
	cmdin = 0;
	break;
      case 0xA001: irq_latch = V; break;
      case 0xC001: irq_reload = 1; break;
      case 0xE000:
	fc->X->IRQEnd(FCEU_IQEXT);
	irq_a = 0;
	break;
      case 0xE001: irq_a = 1; break;
    }
  }

  void M114ExWrite(DECLFW_ARGS) {
    if (A <= 0x7FFF) {
      EXPREGS[0] = V;
      FixMMC3PRG(MMC3_cmd);
    }
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      return ((Mapper114*)fc->fceu->cartiface)->M114Write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5000, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper114*)fc->fceu->cartiface)->M114ExWrite(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    EXPREGS[0] = 0;
    MMC3::Reset();
  }
  
  Mapper114(FC *fc, CartInfo *info)
    : MMC3(fc, info, 256, 256, 0, 0) {
    isRevB = 0;  
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
    fc->state->AddExState(&cmdin, 1, 0, "CMDI");
  }
};

CartInterface *Mapper114_Init(FC *fc, CartInfo *info) {
  return new Mapper114(fc, info);
}

// ---------------------------- Mapper 115 KN-658 board
// ------------------------------

struct Mapper115 : public MMC3 {

  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    // zero 09-apr-2012 - #3515357 - changed to support Bao Qing Tian
    // (mapper 248) which was missing BG gfx. 115 game(s?) seem still
    // to work OK.
    MMC3::PWrap(A, V);
    if (A == 0x8000 && EXPREGS[0] & 0x80)
      fc->cart->setprg16(0x8000, (EXPREGS[0] & 0xF));
  }

  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1(A, (uint32)V | ((EXPREGS[1] & 1) << 8));
  }

  void M115Write(DECLFW_ARGS) {
    // FCEU_printf("%04x:%04x\n",A,V);
    if (A == 0x5080) EXPREGS[2] = V;
    if (A == 0x6000)
      EXPREGS[0] = V;
    else if (A == 0x6001)
      EXPREGS[1] = V;
    FixMMC3PRG(MMC3_cmd);
  }

  DECLFR_RET M115Read(DECLFR_ARGS) {
    return EXPREGS[2];
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x4100, 0x7FFF, [](DECLFW_ARGS) {
      return ((Mapper115*)fc->fceu->cartiface)->M115Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x5000, 0x5FFF, [](DECLFR_ARGS) {
      return ((Mapper115*)fc->fceu->cartiface)->M115Read(DECLFR_FORWARD);
    });
  }

  Mapper115(FC *fc, CartInfo *info)
    : MMC3(fc, info, 128, 512, 0, 0) {
    fc->state->AddExState(EXPREGS, 2, 0, "EXPR");
  }

};

CartInterface *Mapper115_Init(FC *fc, CartInfo *info) {
  return new Mapper115(fc, info);
}

// ---------------------------- Mapper 118 ------------------------------

// only used in UNIF at bottom -tom7

// ---------------------------- Mapper 119 ------------------------------


struct Mapper119 : public MMC3 {
  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1r((V & 0x40) >> 2, A, V & 0x3F);
  }

  Mapper119(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 64, 0, 0) {
    CHRRAMSize = 8192;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
  }
};

CartInterface *Mapper119_Init(FC *fc, CartInfo *info) {
  return new Mapper119(fc, info);
}

// ---------------------------- Mapper 134 ------------------------------

struct Mapper134 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    fc->cart->setprg8(A, (V & 0x1F) | ((EXPREGS[0] & 2) << 4));
  }

  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1(A, (V & 0xFF) | ((EXPREGS[0] & 0x20) << 3));
  }

  void M134Write(DECLFW_ARGS) {
    EXPREGS[0] = V;
    FixMMC3CHR(MMC3_cmd);
    FixMMC3PRG(MMC3_cmd);
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6001, 0x6001, [](DECLFW_ARGS) {
      return ((Mapper134*)fc->fceu->cartiface)->M134Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    EXPREGS[0] = 0;
    MMC3::Reset();
  }

  Mapper134(FC *fc, CartInfo *info)
    : MMC3(fc, info, 256, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 4, 0, "EXPR");  
  }
};
CartInterface *Mapper134_Init(FC *fc, CartInfo *info) {
  return new Mapper134(fc, info);
}

// ---------------------------- Mapper 165 ------------------------------

struct Mapper165 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void CWrap(uint32 A, uint8 V) override {
    if (V == 0)
      fc->cart->setchr4r(0x10, A, 0);
    else
      fc->cart->setchr4(A, V >> 2);
  }

  void M165PPUFD() {
    if (EXPREGS[0] == 0xFD) {
      CWrap(0x0000, DRegBuf[0]);
      CWrap(0x1000, DRegBuf[2]);
    }
  }

  void M165PPUFE() {
    if (EXPREGS[0] == 0xFE) {
      CWrap(0x0000, DRegBuf[1]);
      CWrap(0x1000, DRegBuf[4]);
    }
  }

  // Dead -tom7
  /*
  static void M165CWM(uint32 A, uint8 V) {
    if (((MMC3_cmd & 0x7) == 0) || ((MMC3_cmd & 0x7) == 2)) M165PPUFD();
    if (((MMC3_cmd & 0x7) == 1) || ((MMC3_cmd & 0x7) == 4)) M165PPUFE();
  }
  */

  static void M165PPU(FC *fc, uint32 A) {
    Mapper165 *me = (Mapper165*)fc->fceu->cartiface;
    if ((A & 0x1FF0) == 0x1FD0) {
      me->EXPREGS[0] = 0xFD;
      me->M165PPUFD();
    } else if ((A & 0x1FF0) == 0x1FE0) {
      me->EXPREGS[0] = 0xFE;
      me->M165PPUFE();
    }
  }

  void Power() override {
    EXPREGS[0] = 0xFD;
    MMC3::Power();
  }
  
  Mapper165(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 128, 8, info->battery) {
    fc->ppu->PPU_hook = M165PPU;
    CHRRAMSize = 4096;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");
    fc->state->AddExState(EXPREGS, 4, 0, "EXPR");
  }

};
CartInterface *Mapper165_Init(FC *fc, CartInfo *info) {
  return new Mapper165(fc, info);
}


// ---------------------------- Mapper 191 ------------------------------

struct Mapper191 : public MMC3 {
  void CWrap(uint32 A, uint8 V) override {
    fc->cart->setchr1r((V & 0x80) >> 3, A, V);
  }
  
  Mapper191(FC *fc, CartInfo *info)
    : MMC3(fc, info, 256, 256, 8, info->battery) {
    CHRRAMSize = 2048;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");
  }

};

CartInterface *Mapper191_Init(FC *fc, CartInfo *info) {
  return new Mapper191(fc, info);
}

// ---------------------------- Mapper 192 -------------------------------

struct Mapper192 : public MMC3 {
  void CWrap(uint32 A, uint8 V) override {
    if ((V == 8) || (V == 9) || (V == 0xA) ||
	(V == 0xB))  // Ying Lie Qun Xia Zhuan (Chinese),
      fc->cart->setchr1r(0x10, A, V);
    else
      fc->cart->setchr1r(0, A, V);
  }
  
  Mapper192(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    CHRRAMSize = 4096;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");
  }
};

CartInterface *Mapper192_Init(FC *fc, CartInfo *info) {
  return new Mapper192(fc, info);
}


// ---------------------------- Mapper 194 -------------------------------

struct Mapper194 : public MMC3 {
  void CWrap(uint32 A, uint8 V) override {
    if (V <= 1)  // Dai-2-Ji - Super Robot Taisen (As).nes
      fc->cart->setchr1r(0x10, A, V);
    else
      fc->cart->setchr1r(0, A, V);
  }

  Mapper194(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    CHRRAMSize = 2048;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");
  }
};

CartInterface *Mapper194_Init(FC *fc, CartInfo *info) {
  return new Mapper194(fc, info);
}

// ---------------------------- Mapper 195 -------------------------------

struct Mapper195 : public MMC3 {
  uint8 *wramtw = nullptr;
  uint16 wramsize = 0;

  void CWrap(uint32 A, uint8 V) override {
    if (V <= 3) {
      // Crystalis (c).nes, Captain Tsubasa Vol 2 - Super Striker (C)
      fc->cart->setchr1r(0x10, A, V);
    } else {
      fc->cart->setchr1r(0, A, V);
    }
  }

  void Power() override {
    MMC3::Power();
    fc->cart->setprg4r(0x10, 0x5000, 0);
    fc->fceu->SetWriteHandler(0x5000, 0x5fff, Cart::CartBW);
    fc->fceu->SetReadHandler(0x5000, 0x5fff, Cart::CartBR);
  }

  void Close() override {
    free(wramtw);
    wramtw = nullptr;
  }
  
  Mapper195(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    CHRRAMSize = 4096;
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSize);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSize, 1);
    wramsize = 4096;
    wramtw = (uint8 *)FCEU_gmalloc(wramsize);
    fc->cart->SetupCartPRGMapping(0x10, wramtw, wramsize, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSize, 0, "CHRR");
    fc->state->AddExState(wramtw, wramsize, 0, "TRAM");
  }
};

CartInterface *Mapper195_Init(FC *fc, CartInfo *info) {
  return new Mapper195(fc, info);
}

// ---------------------------- Mapper 196 -------------------------------
// MMC3 board with optional command address line connection, allows to
// make three-four different wirings to IRQ address lines and separately to
// CMD address line, Mali Boss additionally check if wiring are correct for
// game

struct Mapper196 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0]) {
      // Tenchi o Kurau II - Shokatsu Koumei Den (J) (C).nes
      fc->cart->setprg32(0x8000, EXPREGS[1]);
    } else {
      fc->cart->setprg8(A, V);
      // setprg8(A,(V&3)|((V&8)>>1)|((V&4)<<1));    // Mali Splash Bomb
    }
  }

  // In FCEUX, commented out because of "Mali Splash Bomb" -tom7
  // static void M196CW(uint32 A, uint8 V)
  //{
  //  fc->cart->setchr1(A,(V&0xDD)|((V&0x20)>>4)|((V&2)<<4));
  //}

  void Mapper196Write(DECLFW_ARGS) {
    if (A >= 0xC000) {
      A = (A & 0xFFFE) | ((A >> 2) & 1) | ((A >> 3) & 1);
      MMC3_IRQWrite_Direct(DECLFW_FORWARD);
    } else {
      A = (A & 0xFFFE) | ((A >> 2) & 1) | ((A >> 3) & 1) | ((A >> 1) & 1);
      //   A=(A&0xFFFE)|((A>>3)&1); // Mali Splash Bomb
      MMC3_CMDWrite_Direct(DECLFW_FORWARD);
    }
  }

  void Mapper196WriteLo(DECLFW_ARGS) {
    EXPREGS[0] = 1;
    EXPREGS[1] = (V & 0xf) | (V >> 4);
    FixMMC3PRG(MMC3_cmd);
  }

  void Power() override {
    MMC3::Power();
    EXPREGS[0] = EXPREGS[1] = 0;
    fc->fceu->SetWriteHandler(0x6000, 0x6FFF, [](DECLFW_ARGS) {
      return ((Mapper196*)fc->fceu->cartiface)->
	Mapper196WriteLo(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      return ((Mapper196*)fc->fceu->cartiface)->
	Mapper196Write(DECLFW_FORWARD);
    });
  }
  
  Mapper196(FC *fc, CartInfo *info)
    : MMC3(fc, info, 128, 128, 0, 0) {
  }
};
CartInterface *Mapper196_Init(FC *fc, CartInfo *info) {
  return new Mapper196(fc, info);
}

// ---------------------------- Mapper 197 -------------------------------

struct Mapper197 : public MMC3 {
  void CWrap(uint32 A, uint8 V) override {
    if (A == 0x0000)
      fc->cart->setchr4(0x0000, V >> 1);
    else if (A == 0x1000)
      fc->cart->setchr2(0x1000, V);
    else if (A == 0x1400)
      fc->cart->setchr2(0x1800, V);
  }

  Mapper197(FC *fc, CartInfo *info)
    : MMC3(fc, info, 128, 512, 8, 0) {}
};
CartInterface *Mapper197_Init(FC *fc, CartInfo *info) {
  return new Mapper197(fc, info);
}

// ---------------------------- Mapper 198 -------------------------------

struct Mapper198 : public MMC3 {
  uint8 *wramtw = nullptr;
  uint16 wramsize = 0;

  void PWrap(uint32 A, uint8 V) override {
    if (V >= 0x50)  // Tenchi o Kurau II - Shokatsu Koumei Den (J) (C).nes
      fc->cart->setprg8(A, V & 0x4F);
    else
      fc->cart->setprg8(A, V);
  }
  
  Mapper198(FC *fc, CartInfo *info)
    : MMC3(fc, info, 1024, 256, 8, info->battery) {
    wramsize = 4096;
    wramtw = (uint8 *)FCEU_gmalloc(wramsize);
    fc->cart->SetupCartPRGMapping(0x10, wramtw, wramsize, 1);
    fc->state->AddExState(wramtw, wramsize, 0, "TRAM");
  }
};
CartInterface *Mapper198_Init(FC *fc, CartInfo *info) {
  return new Mapper198(fc, info);
}

// ---------------------------- Mapper 205 ------------------------------
// GN-45 BOARD

struct Mapper205 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    // GN-30A - (some badly encoded characters deleted -tom7)
    fc->cart->setprg8(A, (V & 0x0f) | EXPREGS[0]);
  }

  void CWrap(uint32 A, uint8 V) override {
    // GN-30A - (some badly encoded characters deleted -tom7)
    fc->cart->setchr1(A, (V & 0x7F) | (EXPREGS[0] << 3));
  }

  void M205Write(DECLFW_ARGS) {
    if (EXPREGS[2] == 0) {
      EXPREGS[0] = A & 0x30;
      EXPREGS[2] = A & 0x80;
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
    } else {
      Cart::CartBW(DECLFW_FORWARD);
    }
  }

  void Reset() override {
    EXPREGS[0] = EXPREGS[2] = 0;
    MMC3::Reset();
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x6000, 0x6fff, [](DECLFW_ARGS) {
      return ((Mapper205*)fc->fceu->cartiface)->M205Write(DECLFW_FORWARD);
    });
  }
  
  Mapper205(FC *fc, CartInfo *info)
      : MMC3(fc, info, 256, 256, 8, 0) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");  
  }
};
CartInterface *Mapper205_Init(FC *fc, CartInfo *info) {
  return new Mapper205(fc, info);
}

// ---------------------------- Mapper 245 ------------------------------

struct Mapper245 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void CWrap(uint32 A, uint8 V) override {
    if (!fc->unif->UNIFchrrama) {
      // Yong Zhe Dou E Long - Dragon Quest VI
      // (As).nes NEEDS THIS for RAM cart
      fc->cart->setchr1(A, V & 7);
    }
    EXPREGS[0] = V;
    FixMMC3PRG(MMC3_cmd);
  }

  void PWrap(uint32 A, uint8 V) override {
    fc->cart->setprg8(A, (V & 0x3F) | ((EXPREGS[0] & 2) << 5));
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
  }

  Mapper245(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
  }
};

CartInterface *Mapper245_Init(FC *fc, CartInfo *info) {
  return new Mapper245(fc, info);
}

// ---------------------------- Mapper 249 ------------------------------

struct Mapper249 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void PWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x2) {
      if (V < 0x20)
	V = (V & 1) | ((V >> 3) & 2) | ((V >> 1) & 4) | ((V << 2) & 8) |
          ((V << 2) & 0x10);
      else {
	V -= 0x20;
	V = (V & 3) | ((V >> 1) & 4) | ((V >> 4) & 8) | ((V >> 2) & 0x10) |
          ((V << 3) & 0x20) | ((V << 2) & 0xC0);
      }
    }
    fc->cart->setprg8(A, V);
  }

  void CWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x2)
      V = (V & 3) | ((V >> 1) & 4) | ((V >> 4) & 8) | ((V >> 2) & 0x10) |
        ((V << 3) & 0x20) | ((V << 2) & 0xC0);
    fc->cart->setchr1(A, V);
  }

  void M249Write(DECLFW_ARGS) {
    EXPREGS[0] = V;
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Power() override {
    EXPREGS[0] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x5000, 0x5000, [](DECLFW_ARGS) {
      return ((Mapper249*)fc->fceu->cartiface)->M249Write(DECLFW_FORWARD);
    });
  }

  Mapper249(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 1, 0, "EXPR");
  }

};
CartInterface *Mapper249_Init(FC *fc, CartInfo *info) {
  return new Mapper249(fc, info);
}

// ---------------------------- Mapper 250 ------------------------------

struct Mapper250 : public MMC3 {
  void M250Write(DECLFW_ARGS) {
    MMC3_CMDWrite_Direct(fc, (A & 0xE000) | ((A & 0x400) >> 10), A & 0xFF);
  }

  void M250IRQWrite(DECLFW_ARGS) {
    MMC3_IRQWrite_Direct(fc, (A & 0xE000) | ((A & 0x400) >> 10), A & 0xFF);
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
      return ((Mapper250*)fc->fceu->cartiface)->M250Write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xC000, 0xFFFF, [](DECLFW_ARGS) {
      return ((Mapper250*)fc->fceu->cartiface)->M250IRQWrite(DECLFW_FORWARD);
    });
  }
  Mapper250(FC *fc, CartInfo *info)
    : MMC3(fc, info, 512, 256, 8, info->battery) {
  }
};
CartInterface *Mapper250_Init(FC *fc, CartInfo *info) {
  return new Mapper250(fc, info);
}

// ---------------------------- Mapper 254 ------------------------------

namespace {
struct Mapper254 : public MMC3 {
  uint8 EXPREGS[8] = {};

  DECLFR_RET MR254WRAM(DECLFR_ARGS) {
    if (EXPREGS[0])
      return MMC3_WRAM[A - 0x6000];
    else
      return MMC3_WRAM[A - 0x6000] ^ EXPREGS[1];
  }

  void M254Write(DECLFW_ARGS) {
    switch (A) {
      case 0x8000: EXPREGS[0] = 0xff; break;
      case 0xA001: EXPREGS[1] = V;
    }
    MMC3_CMDWrite_Direct(DECLFW_FORWARD);
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
      return ((Mapper254*)fc->fceu->cartiface)->M254Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, [](DECLFR_ARGS) {
      return ((Mapper254*)fc->fceu->cartiface)->MR254WRAM(DECLFR_FORWARD);
    });
  }

  Mapper254(FC *fc, CartInfo *info)
    : MMC3(fc, info, 128, 128, 8, info->battery) {
    fc->state->AddExState(EXPREGS, 2, 0, "EXPR");
  }
};
}

CartInterface *Mapper254_Init(FC *fc, CartInfo *info) {
  return new Mapper254(fc, info);
}

// ---------------------------- UNIF Boards -----------------------------

CartInterface *TBROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 64, 64, 0, 0);
}

CartInterface *TEROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 32, 32, 0, 0);
}

CartInterface *TFROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 512, 64, 0, 0);
}

CartInterface *TGROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 512, 0, 0, 0);
}

CartInterface *TKROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 512, 256, 8, info->battery);
}

CartInterface *TLROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 512, 256, 0, 0);
}

CartInterface *TSROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 512, 256, 8, 0);
}

struct Nom : public MMC3 {
  void MWrap(uint8 V) override {
    A000B = V;
  }
  using MMC3::MMC3;
};

struct Tks : public Nom {
  uint8 PPUCHRBus = 0;
  uint8 TKSMIR[8] = {};
  // From mapper118.
  static void TKSPPU(FC *fc, uint32 A) {
    Tks *me = (Tks*)fc->fceu->cartiface;
    A &= 0x1FFF;
    A >>= 10;
    me->PPUCHRBus = A;
    fc->cart->setmirror(MI_0 + me->TKSMIR[A]);
  }

  void CWrap(uint32 A, uint8 V) override {
    TKSMIR[A >> 10] = V >> 7;
    fc->cart->setchr1(A, V & 0x7F);
    if (PPUCHRBus == (A >> 10)) fc->cart->setmirror(MI_0 + (V >> 7));
  }

  Tks(FC *fc, CartInfo *info, int prg, int chr, int wram, int battery)
    : Nom(fc, info, prg, chr, wram, battery) {
    fc->ppu->PPU_hook = TKSPPU;
    fc->state->AddExState(&PPUCHRBus, 1, 0, "PPUC");
  }
};

CartInterface *TLSROM_Init(FC *fc, CartInfo *info) {
  return new Tks(fc, info, 512, 256, 8, 0);
}

CartInterface *TKSROM_Init(FC *fc, CartInfo *info) {
  return new Tks(fc, info, 512, 256, 8, info->battery);
}

// Code was exactly the same as Mapper119 -tom7
CartInterface *TQROM_Init(FC *fc, CartInfo *info) {
  return new Mapper119(fc, info);
}

CartInterface *HKROM_Init(FC *fc, CartInfo *info) {
  return new MMC3(fc, info, 512, 512, 1, info->battery);
}

