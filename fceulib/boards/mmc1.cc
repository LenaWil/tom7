/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO
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

static int DetectMMC1WRAMSize(uint32 crc32) {
  switch (crc32) {
  case 0xc6182024: /* Romance of the 3 Kingdoms */
  case 0x2225c20f: /* Genghis Khan */
  case 0x4642dda6: /* Nobunaga's Ambition */
  case 0x29449ba9: /* ""        "" (J) */
  case 0x2b11e0b0: /* ""        "" (J) */
  case 0xb8747abf: /* Best Play Pro Yakyuu Special (J) */
  case 0xc9556b36: /* Final Fantasy I & II (J) [!] */
    FCEU_printf(
	" >8KB external WRAM present.  Use UNIF if you hack the ROM "
	"image.\n");
    return 16;
    break;
  default: return 8;
  }
}

struct MMC1 : public CartInterface {
  using CartInterface::CartInterface;

  void GenMMC1Power(FC *fc);
  void GenMMC1Init(CartInfo *info, int prg, int chr, int wram,
		   int battery);

  uint8 DRegs[4] = {};
  uint8 Buffer = 0, BufferShift = 0;

  int mmc1opts = 0;

  // Used to play some tricks with function pointers; this is
  // simpler and avoids creating more subclasses. -tom7
  bool is_105 = false;

  // These were only used by mapper 105.
  // XXX tom7
    // void (MMC1::*MMC1CHRHook4)(uint32 A, uint8 V) = nullptr;
  // void (MMC1::*MMC1PRGHook16)(uint32 A, uint8 V) = nullptr;

  uint8 *WRAM = nullptr;
  uint8 *CHRRAM = nullptr;
  int is155 = 0, is171 = 0;

  uint64 lreset = 0ULL;
  
  static DECLFW(MBWRAM) {
    return ((MMC1*)fc->fceu->cartiface)->MBWRAM_Direct(DECLFW_FORWARD);
  }

  void MBWRAM_Direct(DECLFW_ARGS) {
    if (!(DRegs[3] & 0x10) || is155)
      fc->cart->Page[A >> 11][A] = V;  // WRAM is enabled.
  }

  static DECLFR(MAWRAM) {
    return ((MMC1*)fc->fceu->cartiface)->MAWRAM_Direct(DECLFR_FORWARD);
  }

  DECLFR_RET MAWRAM_Direct(DECLFR_ARGS) {
    if ((DRegs[3] & 0x10) && !is155)
      return fc->X->DB;  // WRAM is disabled
    return fc->cart->Page[A >> 11][A];
  }

  void MMC1CHR() {
    if (mmc1opts & 4) {
      if (DRegs[0] & 0x10)
	fc->cart->setprg8r(0x10, 0x6000, (DRegs[1] >> 4) & 1);
      else
	fc->cart->setprg8r(0x10, 0x6000, (DRegs[1] >> 3) & 1);
    }

    if (is_105) {
      if (DRegs[0] & 0x10) {
	NWCCHRHook(0x0000, DRegs[1]);
	NWCCHRHook(0x1000, DRegs[2]);
      } else {
	NWCCHRHook(0x0000, (DRegs[1] & 0xFE));
	NWCCHRHook(0x1000, DRegs[1] | 1);
      }
    } else {
      if (DRegs[0] & 0x10) {
	fc->cart->setchr4(0x0000, DRegs[1]);
	fc->cart->setchr4(0x1000, DRegs[2]);
      } else
	fc->cart->setchr8(DRegs[1] >> 1);
    }
  }

  void MMC1PRG() {
    uint8 offs = DRegs[1] & 0x10;
    if (is_105) {
      switch (DRegs[0] & 0xC) {
	case 0xC:
	  NWCPRGHook(0x8000, (DRegs[3] + offs));
	  NWCPRGHook(0xC000, 0xF + offs);
	  break;
	case 0x8:
	  NWCPRGHook(0xC000, (DRegs[3] + offs));
	  NWCPRGHook(0x8000, offs);
	  break;
	case 0x0:
	case 0x4:
	  NWCPRGHook(0x8000, ((DRegs[3] & ~1) + offs));
	  NWCPRGHook(0xc000, ((DRegs[3] & ~1) + offs + 1));
	  break;
      }
    } else {
      switch (DRegs[0] & 0xC) {
	case 0xC:
	  fc->cart->setprg16(0x8000, (DRegs[3] + offs));
	  fc->cart->setprg16(0xC000, 0xF + offs);
	  break;
	case 0x8:
	  fc->cart->setprg16(0xC000, (DRegs[3] + offs));
	  fc->cart->setprg16(0x8000, offs);
	  break;
	case 0x0:
	case 0x4:
	  fc->cart->setprg16(0x8000, ((DRegs[3] & ~1) + offs));
	  fc->cart->setprg16(0xc000, ((DRegs[3] & ~1) + offs + 1));
	  break;
      }
    }
  }

  void MMC1MIRROR() {
    if (!is171) switch (DRegs[0] & 3) {
	case 2: fc->cart->setmirror(MI_V); break;
	case 3: fc->cart->setmirror(MI_H); break;
	case 0: fc->cart->setmirror(MI_0); break;
	case 1: fc->cart->setmirror(MI_1); break;
      }
  }

  static DECLFW(MMC1_write) {
    return ((MMC1*)fc->fceu->cartiface)->MMC1_write_Direct(DECLFW_FORWARD);
  }
    
  void MMC1_write_Direct(DECLFW_ARGS) {
    int n = (A >> 13) - 4;
    // FCEU_DispMessage("%016x",fc->fceu->timestampbase+fc->X->timestamp);
    //  FCEU_printf("$%04x:$%02x, $%04x\n",A,V,fc->X->PC);
    // DumpMem("out",0xe000,0xffff);

    /* The MMC1 is busy so ignore the write. */
    /* As of version FCE Ultra 0.81, the timestamp is only
       increased before each instruction is executed(in other words
       precision isn't that great), but this should still work to
       deal with 2 writes in a row from a single RMW instruction. */
    if ((fc->fceu->timestampbase + fc->X->timestamp) < (lreset + 2))
      return;
    //  FCEU_printf("Write %04x:%02x\n",A,V);
    if (V & 0x80) {
      DRegs[0] |= 0xC;
      BufferShift = Buffer = 0;
      MMC1PRG();
      lreset = fc->fceu->timestampbase + fc->X->timestamp;
      return;
    }

    Buffer |= (V & 1) << (BufferShift++);

    if (BufferShift == 5) {
      DRegs[n] = Buffer;
      BufferShift = Buffer = 0;
      switch (n) {
      case 0:
        MMC1MIRROR();
        MMC1CHR();
        MMC1PRG();
        break;
      case 1:
        MMC1CHR();
        MMC1PRG();
        break;
      case 2: MMC1CHR(); break;
      case 3: MMC1PRG(); break;
      }
    }
  }

  static void MMC1_Restore(FC *fc, int version) {
    MMC1 *me = (MMC1*)fc->fceu->cartiface;
    me->MMC1MIRROR();
    me->MMC1CHR();
    me->MMC1PRG();
    me->lreset = 0; /* timestamp(base) is not stored in save states. */
  }

  void MMC1CMReset() {
    for (int i = 0; i < 4; i++) DRegs[i] = 0;
    Buffer = BufferShift = 0;
    DRegs[0] = 0x1F;

    DRegs[1] = 0;
    DRegs[2] = 0;  // Should this be something other than 0?
    DRegs[3] = 0;

    MMC1MIRROR();
    MMC1CHR();
    MMC1PRG();
  }

  uint32 NWCIRQCount = 0;
  uint8 NWCRec = 0;
  #define NWCDIP 0xE

  // Used in mapper 105.
  static void NWCIRQHook(FC *fc, int a) {
    MMC1 *me = (MMC1*)fc->fceu->cartiface;
    if (!(me->NWCRec & 0x10)) {
      me->NWCIRQCount += a;
      if ((me->NWCIRQCount | (NWCDIP << 25)) >= 0x3e000000) {
	me->NWCIRQCount = 0;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  void NWCCHRHook(uint32 A, uint8 V) {
    if ((V & 0x10)) {  // && !(NWCRec&0x10))
      NWCIRQCount = 0;
      fc->X->IRQEnd(FCEU_IQEXT);
    }

    NWCRec = V;
    if (V & 0x08)
      MMC1PRG();
    else
      fc->cart->setprg32(0x8000, (V >> 1) & 3);
  }

  void NWCPRGHook(uint32 A, uint8 V) {
    if (NWCRec & 0x8)
      fc->cart->setprg16(A, 8 | (V & 0x7));
    else
      fc->cart->setprg32(0x8000, (NWCRec >> 1) & 3);
  }

  void Power() override {
    lreset = 0;
    if (mmc1opts & 1) {
      // FCEU_CheatAddRAM(8,0x6000,WRAM);
      if (mmc1opts & 4) {
	FCEU_dwmemset(WRAM, 0, 8192);
      } else if (!(mmc1opts & 2)) {
	FCEU_dwmemset(WRAM, 0, 8192);
      }
    }
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, MMC1_write);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);

    if (mmc1opts & 1) {
      fc->fceu->SetReadHandler(0x6000, 0x7FFF, MAWRAM);
      fc->fceu->SetWriteHandler(0x6000, 0x7FFF, MBWRAM);
      fc->cart->setprg8r(0x10, 0x6000, 0);
    }

    MMC1CMReset();

    if (is_105) {
      fc->cart->setchr8r(0, 0);
    }
  }

  void Close() override {
    free(CHRRAM);
    free(WRAM);
    CHRRAM = WRAM = nullptr;
  }

  MMC1(FC *fc, CartInfo *info, int prg, int chr, int wram,
       int battery) : CartInterface(fc), is155(0) {

    mmc1opts = 0;
    fc->cart->PRGmask16[0] &= (prg >> 14) - 1;
    fc->cart->CHRmask4[0] &= (chr >> 12) - 1;
    fc->cart->CHRmask8[0] &= (chr >> 13) - 1;

    if (wram) {
      WRAM = (uint8 *)FCEU_gmalloc(wram * 1024);
      // mbg 17-jun-08 - this shouldve been cleared to re-initialize save ram
      // ch4 10-dec-08 - nope, this souldn't
      // mbg 29-mar-09 - no time to debate this, we need to keep from breaking
      // some old stuff.
      // we really need to make up a policy for how compatibility and
      // accuracy can be resolved.
      memset(WRAM, 0, wram * 1024);
      mmc1opts |= 1;
      if (wram > 8) mmc1opts |= 4;
      fc->cart->SetupCartPRGMapping(0x10, WRAM, wram * 1024, 1);
      fc->state->AddExState(WRAM, wram * 1024, 0, "WRAM");
      if (battery) {
	mmc1opts |= 2;
	info->SaveGame[0] = WRAM + ((mmc1opts & 4) ? 8192 : 0);
	info->SaveGameLen[0] = 8192;
      }
    }
    if (!chr) {
      CHRRAM = (uint8 *)FCEU_gmalloc(8192);
      fc->cart->SetupCartCHRMapping(0, CHRRAM, 8192, 1);
      fc->state->AddExState(CHRRAM, 8192, 0, "CHRR");
    }
    fc->state->AddExState(DRegs, 4, 0, "DREG");

    fc->fceu->GameStateRestore = MMC1_Restore;
    fc->state->AddExState(&lreset, 8, 1, "LRST");
    fc->state->AddExState(&Buffer, 1, 1, "BFFR");
    fc->state->AddExState(&BufferShift, 1, 1, "BFRS");
  }
};
  
CartInterface *Mapper105_Init(FC *fc, CartInfo *info) {
  MMC1 *mmc = new MMC1(fc, info, 256, 256, 8, 0);
  mmc->is_105 = true;
  fc->X->MapIRQHook = MMC1::NWCIRQHook;
  return mmc;
}


CartInterface *Mapper1_Init(FC *fc, CartInfo *info) {
  int ws = DetectMMC1WRAMSize(info->CRC32);
  return new MMC1(fc, info, 512, 256, ws, info->battery);
}

/* Same as mapper 1, without respect for WRAM enable bit. */
CartInterface *Mapper155_Init(FC *fc, CartInfo *info) {
  MMC1 *mmc1 = new MMC1(fc, info, 512, 256, 8, info->battery);
  mmc1->is155 = 1;
  return mmc1;
}

/* Same as mapper 1, with different (or without) mirroring control. */
/* Kaiser KS7058 board, KS203 custom chip */
CartInterface *Mapper171_Init(FC *fc, CartInfo *info) {
  MMC1 *mmc1 = new MMC1(fc, info, 32, 32, 0, 0);
  mmc1->is171 = 1;
  return mmc1;
}

CartInterface *SAROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 128, 64, 8, info->battery);
}

CartInterface *SBROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 128, 64, 0, 0);
}

CartInterface *SCROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 128, 128, 0, 0);
}

CartInterface *SEROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 32, 64, 0, 0);
}

CartInterface *SGROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 0, 0, 0);
}

CartInterface *SKROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 64, 8, info->battery);
}

CartInterface *SLROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 128, 0, 0);
}

CartInterface *SL1ROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 128, 128, 0, 0);
}

/* Begin unknown - may be wrong - perhaps they use different MMC1s from the
   similarly functioning boards?
*/

CartInterface *SL2ROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 256, 0, 0);
}

CartInterface *SFROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 256, 0, 0);
}

CartInterface *SHROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 256, 0, 0);
}

/* End unknown  */
/*              */
/*              */

CartInterface *SNROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 0, 8, info->battery);
}

CartInterface *SOROM_Init(FC *fc, CartInfo *info) {
  return new MMC1(fc, info, 256, 0, 16, info->battery);
}
