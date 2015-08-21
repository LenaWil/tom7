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

/* None of this code should use any of the iNES bank switching wrappers. */

#include "mapinc.h"

namespace {
struct MMC5APU {
  uint16 wl[2] = {};
  uint8 env[2] = {};
  uint8 enable = 0;
  uint8 running = 0;
  uint8 raw = 0;
  uint8 rawcontrol = 0;
  int32 dcount[2] = {};
  int32 BC[3] = {};
  int32 vcount[2] = {};
};


struct CartData {
  const uint32 crc32;
  const uint8 size;
};

static constexpr CartData const MMC5CartList[] = {
  {0x9c18762b, 2}, /* L'Empereur */
  {0x26533405, 2},
  {0x6396b988, 2},
  {0xaca15643, 2}, /* Uncharted Waters */
  {0xfe3488d1, 2}, /* Dai Koukai Jidai */
  {0x15fe6d0f, 2}, /* BKAC             */
  {0x39f2ce4b, 2}, /* Suikoden              */
  {0x8ce478db, 2}, /* Nobunaga's Ambition 2 */
  {0xeee9a682, 2},
  {0xf9b4240f, 2},
  {0x1ced086f, 2}, /* Ishin no Arashi */
  {0xf540677b, 4}, /* Nobunaga...Bushou Fuuun Roku */
  {0x6f4e4312, 4}, /* Aoki Ookami..Genchou */
  {0xf011e490, 4}, /* Romance of the 3 Kingdoms 2 */
  {0x184c2124, 4}, /* Sangokushi 2 */
  {0xee8e6553, 4},
};

static constexpr int MMC5_NUM_CARTS =
  sizeof (MMC5CartList) / sizeof (MMC5CartList[0]);

static int DetectMMC5WRAMSize(uint32 crc32) {
  for (int x = 0; x < MMC5_NUM_CARTS; x++) {
    if (crc32 == MMC5CartList[x].crc32) {
      FCEU_printf(
	  " >8KB external WRAM present.  Use UNIF if you hack the ROM "
	  "image.\n");
      return MMC5CartList[x].size * 8;
    }
  }

  // mbg 04-aug-08 - previously, this was returning 8KB
  // but I changed it to return 64 because unlisted carts are probably
  // homebrews, and they should probably use 64 (why not use it all?)
  // ch4 10-dec-08 - then f***ng for what all this shit above? let's give em all
  // this 64k shit! Damn
  //               homebrew must use it's own emulators or standart features.
  // adelikat 20-dec-08 - reverting back to return 64, sounds like it was
  // changed back to 8 simply on principle.  FCEUX is all encompassing, and that
  // include
  // rom-hacking.  We want it to be the best emulator for such purposes.  So
  // unless return 64 harms compatibility with anything else, I see now reason
  // not to have it
  // mbg 29-mar-09 - I should note that mmc5 is in principle capable of 64KB,
  // even if no real carts ever supported it.
  // This does not in principle break any games which share this mapper, and it
  // should be OK for homebrew.
  // if there are games which need 8KB instead of 64KB default then lets add
  // them to the list
  return 64;
}

struct MMC5 : public CartInterface {
  MMC5APU MMC5Sound;

  uint8 PRGBanks[4] = {};
  uint8 WRAMPage = 0;
  uint16 CHRBanksA[8] = {}, CHRBanksB[4] = {};
  uint8 WRAMMaskEnable[2] = {};
  // Used in ppu -tom7
  // uint8 mmc5ABMode = 0; /* A=0, B=1 */

  uint8 IRQScanline = 0, IRQEnable = 0;
  uint8 CHRMode = 0, NTAMirroring = 0, NTFill = 0, ATFill = 0;

  uint8 MMC5IRQR = 0;
  uint8 MMC5LineCounter = 0;
  uint8 mmc5psize = 0, mmc5vsize = 0;
  uint8 mul[2] = {};

  uint8 *WRAM = nullptr;
  uint8 *MMC5fill = nullptr;
  uint8 *ExRAM = nullptr;

  uint8 MMC5WRAMsize = 0;
  uint8 MMC5WRAMIndex[8] = {};

  uint8 MMC5ROMWrProtect[4] = {};
  uint8 MMC5MemIn[5] = {};
  
  void (MMC5::*sfun)(int P) = nullptr;
  void (MMC5::*psfun)() = nullptr;

  inline void MMC5SPRVROM_BANK1(uint32 A, uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask1[0];
      fc->cart->MMC5SPRVPage[(A) >> 10] =
	  &fc->cart->CHRptr[0][(V) << 10] - (A);
    }
  }

  inline void MMC5BGVROM_BANK1(uint32 A, uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask1[0];
      fc->cart->MMC5BGVPage[(A) >> 10] =
	  &fc->cart->CHRptr[0][(V) << 10] - (A);
    }
  }

  inline void MMC5SPRVROM_BANK2(uint32 A, uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask2[0];
      fc->cart->MMC5SPRVPage[(A) >> 10] =
	  fc->cart->MMC5SPRVPage[((A) >> 10) + 1] =
	      &fc->cart->CHRptr[0][(V) << 11] - (A);
    }
  }

  inline void MMC5BGVROM_BANK2(uint32 A, uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask2[0];
      fc->cart->MMC5BGVPage[(A) >> 10] =
	  fc->cart->MMC5BGVPage[((A) >> 10) + 1] =
	      &fc->cart->CHRptr[0][(V) << 11] - (A);
    }
  }

  inline void MMC5SPRVROM_BANK4(uint32 A, uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask4[0];
      fc->cart->MMC5SPRVPage[(A) >> 10] =
	  fc->cart->MMC5SPRVPage[((A) >> 10) + 1] =
	      fc->cart->MMC5SPRVPage[((A) >> 10) + 2] =
		  fc->cart->MMC5SPRVPage[((A) >> 10) + 3] =
		      &fc->cart->CHRptr[0][(V) << 12] - (A);
    }
  }

  inline void MMC5BGVROM_BANK4(uint32 A, uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask4[0];
      fc->cart->MMC5BGVPage[(A) >> 10] =
	  fc->cart->MMC5BGVPage[((A) >> 10) + 1] =
	      fc->cart->MMC5BGVPage[((A) >> 10) + 2] =
		  fc->cart->MMC5BGVPage[((A) >> 10) + 3] =
		      &fc->cart->CHRptr[0][(V) << 12] - (A);
    }
  }

  inline void MMC5SPRVROM_BANK8(uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask8[0];
      fc->cart->MMC5SPRVPage[0] = fc->cart->MMC5SPRVPage[1] =
	  fc->cart->MMC5SPRVPage[2] = fc->cart->MMC5SPRVPage[3] =
	      fc->cart->MMC5SPRVPage[4] = fc->cart->MMC5SPRVPage[5] =
		  fc->cart->MMC5SPRVPage[6] =
		      fc->cart->MMC5SPRVPage[7] =
			  &fc->cart->CHRptr[0][(V) << 13];
    }
  }

  inline void MMC5BGVROM_BANK8(uint32 V) {
    if (fc->cart->CHRptr[0]) {
      V &= fc->cart->CHRmask8[0];
      fc->cart->MMC5BGVPage[0] = fc->cart->MMC5BGVPage[1] =
	  fc->cart->MMC5BGVPage[2] = fc->cart->MMC5BGVPage[3] =
	      fc->cart->MMC5BGVPage[4] = fc->cart->MMC5BGVPage[5] =
		  fc->cart->MMC5BGVPage[6] =
		      fc->cart->MMC5BGVPage[7] =
			  &fc->cart->CHRptr[0][(V) << 13];
    }
  }

  void BuildWRAMSizeTable() {
    for (int x = 0; x < 8; x++) {
      switch (MMC5WRAMsize) {
	case 0: MMC5WRAMIndex[x] = 255; break;  // X,X,X,X,X,X,X,X
	case 1: MMC5WRAMIndex[x] = (x > 3) ? 255 : 0; break;  // 0,0,0,0,X,X,X,X
	case 2: MMC5WRAMIndex[x] = (x & 4) >> 2; break;  // 0,0,0,0,1,1,1,1
	case 4:
	  MMC5WRAMIndex[x] = (x > 3) ? 255 : (x & 3);
	  break;  // 0,1,2,3,X,X,X,X
	case 8:
	  MMC5WRAMIndex[x] = x;
	  break;  // 0,1,2,3,4,5,6,7,8
	  // mbg 8/6/08 - i added this to support 64KB of wram
	  // now, I have at least one example (laser invasion) which
	  // actually uses size 1 but isnt in the crc list so, whereas
	  // before my change on 8/4/08 we would have selected size 1, now
	  // we select size 8 this means that we could have just introduced
	  // an emulation bug, in case those games happened to address,
	  // say, page 3. with size 1 that would resolve to [0] but in size
	  // 8 it resolves to [3]. so, you know what to do if there are
	  // problems.
      }
    }
  }

  void MMC5CHRA() {
    switch (mmc5vsize & 3) {
      case 0:
	fc->cart->setchr8(CHRBanksA[7]);
	MMC5SPRVROM_BANK8(CHRBanksA[7]);
	break;
      case 1:
	fc->cart->setchr4(0x0000, CHRBanksA[3]);
	fc->cart->setchr4(0x1000, CHRBanksA[7]);
	MMC5SPRVROM_BANK4(0x0000, CHRBanksA[3]);
	MMC5SPRVROM_BANK4(0x1000, CHRBanksA[7]);
	break;
      case 2:
	fc->cart->setchr2(0x0000, CHRBanksA[1]);
	fc->cart->setchr2(0x0800, CHRBanksA[3]);
	fc->cart->setchr2(0x1000, CHRBanksA[5]);
	fc->cart->setchr2(0x1800, CHRBanksA[7]);
	MMC5SPRVROM_BANK2(0x0000, CHRBanksA[1]);
	MMC5SPRVROM_BANK2(0x0800, CHRBanksA[3]);
	MMC5SPRVROM_BANK2(0x1000, CHRBanksA[5]);
	MMC5SPRVROM_BANK2(0x1800, CHRBanksA[7]);
	break;
      case 3:
	for (int x = 0; x < 8; x++) {
	  fc->cart->setchr1(x << 10, CHRBanksA[x]);
	  MMC5SPRVROM_BANK1(x << 10, CHRBanksA[x]);
	}
	break;
    }
  }

  void MMC5CHRB() {
    switch (mmc5vsize & 3) {
      case 0:
	fc->cart->setchr8(CHRBanksB[3]);
	MMC5BGVROM_BANK8(CHRBanksB[3]);
	break;
      case 1:
	fc->cart->setchr4(0x0000, CHRBanksB[3]);
	fc->cart->setchr4(0x1000, CHRBanksB[3]);
	MMC5BGVROM_BANK4(0x0000, CHRBanksB[3]);
	MMC5BGVROM_BANK4(0x1000, CHRBanksB[3]);
	break;
      case 2:
	fc->cart->setchr2(0x0000, CHRBanksB[1]);
	fc->cart->setchr2(0x0800, CHRBanksB[3]);
	fc->cart->setchr2(0x1000, CHRBanksB[1]);
	fc->cart->setchr2(0x1800, CHRBanksB[3]);
	MMC5BGVROM_BANK2(0x0000, CHRBanksB[1]);
	MMC5BGVROM_BANK2(0x0800, CHRBanksB[3]);
	MMC5BGVROM_BANK2(0x1000, CHRBanksB[1]);
	MMC5BGVROM_BANK2(0x1800, CHRBanksB[3]);
	break;
      case 3:
	for (int x = 0; x < 8; x++) {
	  fc->cart->setchr1(x << 10, CHRBanksB[x & 3]);
	  MMC5BGVROM_BANK1(x << 10, CHRBanksB[x & 3]);
	}
	break;
    }
  }

  void MMC5WRAM(uint32 A, uint32 V) {
    // printf("%02x\n",V);
    V = MMC5WRAMIndex[V & 7];
    if (V != 255) {
      fc->cart->setprg8r(0x10, A, V);
      MMC5MemIn[(A - 0x6000) >> 13] = 1;
    } else {
      MMC5MemIn[(A - 0x6000) >> 13] = 0;
    }
  }

  void MMC5PRG() {
    switch (mmc5psize & 3) {
      case 0:
	MMC5ROMWrProtect[0] = MMC5ROMWrProtect[1] = MMC5ROMWrProtect[2] =
	    MMC5ROMWrProtect[3] = 1;
	fc->cart->setprg32(0x8000, ((PRGBanks[1] & 0x7F) >> 2));
	for (int x = 0; x < 4; x++) MMC5MemIn[1 + x] = 1;
	break;
      case 1:
	if (PRGBanks[1] & 0x80) {
	  MMC5ROMWrProtect[0] = MMC5ROMWrProtect[1] = 1;
	  fc->cart->setprg16(0x8000, (PRGBanks[1] >> 1));
	  MMC5MemIn[1] = MMC5MemIn[2] = 1;
	} else {
	  MMC5ROMWrProtect[0] = MMC5ROMWrProtect[1] = 0;
	  MMC5WRAM(0x8000, PRGBanks[1] & 7 & 0xFE);
	  MMC5WRAM(0xA000, (PRGBanks[1] & 7 & 0xFE) + 1);
	}
	MMC5MemIn[3] = MMC5MemIn[4] = 1;
	MMC5ROMWrProtect[2] = MMC5ROMWrProtect[3] = 1;
	fc->cart->setprg16(0xC000, (PRGBanks[3] & 0x7F) >> 1);
	break;
      case 2:
	if (PRGBanks[1] & 0x80) {
	  MMC5MemIn[1] = MMC5MemIn[2] = 1;
	  MMC5ROMWrProtect[0] = MMC5ROMWrProtect[1] = 1;
	  fc->cart->setprg16(0x8000, (PRGBanks[1] & 0x7F) >> 1);
	} else {
	  MMC5ROMWrProtect[0] = MMC5ROMWrProtect[1] = 0;
	  MMC5WRAM(0x8000, PRGBanks[1] & 7 & 0xFE);
	  MMC5WRAM(0xA000, (PRGBanks[1] & 7 & 0xFE) + 1);
	}
	if (PRGBanks[2] & 0x80) {
	  MMC5ROMWrProtect[2] = 1;
	  MMC5MemIn[3] = 1;
	  fc->cart->setprg8(0xC000, PRGBanks[2] & 0x7F);
	} else {
	  MMC5ROMWrProtect[2] = 0;
	  MMC5WRAM(0xC000, PRGBanks[2] & 7);
	}
	MMC5MemIn[4] = 1;
	MMC5ROMWrProtect[3] = 1;
	fc->cart->setprg8(0xE000, PRGBanks[3] & 0x7F);
	break;
      case 3:
	for (int x = 0; x < 3; x++) {
	  if (PRGBanks[x] & 0x80) {
	    MMC5ROMWrProtect[x] = 1;
	    fc->cart->setprg8(0x8000 + (x << 13), PRGBanks[x] & 0x7F);
	    MMC5MemIn[1 + x] = 1;
	  } else {
	    MMC5ROMWrProtect[x] = 0;
	    MMC5WRAM(0x8000 + (x << 13), PRGBanks[x] & 7);
	  }
	}
	MMC5MemIn[4] = 1;
	MMC5ROMWrProtect[3] = 1;
	fc->cart->setprg8(0xE000, PRGBanks[3] & 0x7F);
	break;
    }
  }

  void Mapper5_write(DECLFW_ARGS) {
    if (A >= 0x5120 && A <= 0x5127) {
      fc->ppu->mmc5ABMode = 0;
      // if we had a test case for this then we could test this, but it
      // hasnt been verified
      CHRBanksA[A & 7] = V | ((fc->ppu->MMC50x5130 & 0x3) << 8);
      // CHRBanksA[A&7]=V;
      MMC5CHRA();
    } else {
      switch (A) {
	case 0x5105: {
	  for (int x = 0; x < 4; x++) {
	    switch ((V >> (x << 1)) & 3) {
	      case 0:
		fc->ppu->PPUNTARAM |= 1 << x;
		fc->ppu->vnapage[x] = fc->ppu->NTARAM;
		break;
	      case 1:
		fc->ppu->PPUNTARAM |= 1 << x;
		fc->ppu->vnapage[x] = fc->ppu->NTARAM + 0x400;
		break;
	      case 2:
		fc->ppu->PPUNTARAM |= 1 << x;
		fc->ppu->vnapage[x] = ExRAM;
		break;
	      case 3:
		fc->ppu->PPUNTARAM &= ~(1 << x);
		fc->ppu->vnapage[x] = MMC5fill;
		break;
	    }
	  }
	  NTAMirroring = V;
	  break;
	}
	case 0x5113:
	  WRAMPage = V;
	  MMC5WRAM(0x6000, V & 7);
	  break;
	case 0x5100:
	  mmc5psize = V;
	  MMC5PRG();
	  break;
	case 0x5101:
	  mmc5vsize = V;
	  if (!fc->ppu->mmc5ABMode) {
	    MMC5CHRB();
	    MMC5CHRA();
	  } else {
	    MMC5CHRA();
	    MMC5CHRB();
	  }
	  break;
	case 0x5114:
	case 0x5115:
	case 0x5116:
	case 0x5117:
	  PRGBanks[A & 3] = V;
	  MMC5PRG();
	  break;
	case 0x5128:
	case 0x5129:
	case 0x512a:
	case 0x512b:
	  fc->ppu->mmc5ABMode = 1;
	  CHRBanksB[A & 3] = V;
	  MMC5CHRB();
	  break;
	case 0x5102: WRAMMaskEnable[0] = V; break;
	case 0x5103: WRAMMaskEnable[1] = V; break;
	case 0x5104:
	  CHRMode = V;
	  fc->ppu->MMC5HackCHRMode = V & 3;
	  break;
	case 0x5106:
	  if (V != NTFill) {
	    uint32 t = V | (V << 8) | (V << 16) | (V << 24);
	    FCEU_dwmemset(MMC5fill, t, 0x3c0);
	  }
	  NTFill = V;
	  break;
	case 0x5107:
	  if (V != ATFill) {
	    unsigned char moop;
	    uint32 t;
	    moop = V | (V << 2) | (V << 4) | (V << 6);
	    t = moop | (moop << 8) | (moop << 16) | (moop << 24);
	    FCEU_dwmemset(MMC5fill + 0x3c0, t, 0x40);
	  }
	  ATFill = V;
	  break;
	case 0x5130: fc->ppu->MMC50x5130 = V; break;
	case 0x5200: fc->ppu->MMC5HackSPMode = V; break;
	case 0x5201: fc->ppu->MMC5HackSPScroll = (V >> 3) & 0x1F; break;
	case 0x5202: fc->ppu->MMC5HackSPPage = V & 0x3F; break;
	case 0x5203:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQScanline = V;
	  break;
	case 0x5204:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQEnable = V & 0x80;
	  break;
	case 0x5205: mul[0] = V; break;
	case 0x5206: mul[1] = V; break;
      }
    }
  }

  DECLFR_RET MMC5_ReadROMRAM(DECLFR_ARGS) {
    if (MMC5MemIn[(A - 0x6000) >> 13])
      return fc->cart->Page[A >> 11][A];
    else
      return fc->X->DB;
  }

  void MMC5_WriteROMRAM(DECLFW_ARGS) {
    if (A >= 0x8000)
      if (MMC5ROMWrProtect[(A - 0x8000) >> 13]) return;
    if (MMC5MemIn[(A - 0x6000) >> 13])
      if (((WRAMMaskEnable[0] & 3) | ((WRAMMaskEnable[1] & 3) << 2)) == 6)
	fc->cart->Page[A >> 11][A] = V;
  }

  void MMC5_ExRAMWr(DECLFW_ARGS) {
    if (fc->ppu->MMC5HackCHRMode != 3) ExRAM[A & 0x3ff] = V;
  }

  DECLFR_RET MMC5_ExRAMRd(DECLFR_ARGS) {
    /* Not sure if this is correct, so I'll comment it out for now. */
    // if (MMC5HackCHRMode>=2)
    return ExRAM[A & 0x3ff];
    // else
    // return(fc->X->DB);
  }

  DECLFR_RET MMC5_read(DECLFR_ARGS) {
    TRACEF("MMC5_read %d %02x %02x", A, mul[0], mul[1]);
    switch (A) {
      case 0x5204: {
	fc->X->IRQEnd(FCEU_IQEXT);

	uint8 x = MMC5IRQR;

	MMC5IRQR &= 0x40;
	return x;
      }
      case 0x5205: return (mul[0] * mul[1]);
      case 0x5206: return ((mul[0] * mul[1]) >> 8);
    }
    return fc->X->DB;
  }

  void MMC5Synco() {
    MMC5PRG();
    for (int x = 0; x < 4; x++) {
      switch ((NTAMirroring >> (x << 1)) & 3) {
	case 0:
	  fc->ppu->PPUNTARAM |= 1 << x;
	  fc->ppu->vnapage[x] = fc->ppu->NTARAM;
	  break;
	case 1:
	  fc->ppu->PPUNTARAM |= 1 << x;
	  fc->ppu->vnapage[x] = fc->ppu->NTARAM + 0x400;
	  break;
	case 2:
	  fc->ppu->PPUNTARAM |= 1 << x;
	  fc->ppu->vnapage[x] = ExRAM;
	  break;
	case 3:
	  fc->ppu->PPUNTARAM &= ~(1 << x);
	  fc->ppu->vnapage[x] = MMC5fill;
	  break;
      }
    }
    MMC5WRAM(0x6000, WRAMPage & 7);
    if (!fc->ppu->mmc5ABMode) {
      MMC5CHRB();
      MMC5CHRA();
    } else {
      MMC5CHRA();
      MMC5CHRB();
    }

    {
      uint32 t = NTFill | (NTFill << 8) | (NTFill << 16) | (NTFill << 24);
      FCEU_dwmemset(MMC5fill, t, 0x3c0);
    }

    {
      unsigned char moop =
	ATFill | (ATFill << 2) | (ATFill << 4) | (ATFill << 6);
      uint32 t = moop | (moop << 8) | (moop << 16) | (moop << 24);
      FCEU_dwmemset(MMC5fill + 0x3c0, t, 0x40);
    }
    fc->X->IRQEnd(FCEU_IQEXT);
    fc->ppu->MMC5HackCHRMode = CHRMode & 3;
  }

  // Rather than having the PPU directly call into MMC5 code, this is
  // exposed in the cart interface just for MMC5. Still gross...
  void MMC5HackHB(int scanline) override {
    TRACEF("MMC5_hb %d %02x %02x", scanline, MMC5LineCounter, MMC5IRQR);
    if (scanline == 240) {
      MMC5LineCounter = 0;
      MMC5IRQR = 0x40;
      return;
    }
    if (MMC5LineCounter < 240) {
      if (MMC5LineCounter == IRQScanline) {
	MMC5IRQR |= 0x80;
	if (IRQEnable & 0x80) {
	  fc->X->IRQBegin(FCEU_IQEXT);
	}
      }
      MMC5LineCounter++;
    }
    if (MMC5LineCounter == 240) {
      MMC5IRQR = 0;
    }
  }

  static void MMC5_StateRestore(FC *fc, int version) {
    ((MMC5*)fc->fceu->cartiface)->MMC5Synco();
  }

  void Do5PCM() {
    int32 V;
    int32 start, end;

    start = MMC5Sound.BC[2];
    end = (fc->sound->SoundTS() << 16) / fc->sound->soundtsinc;
    if (end <= start) return;
    MMC5Sound.BC[2] = end;

    if (!(MMC5Sound.rawcontrol & 0x40) && MMC5Sound.raw)
      for (V = start; V < end; V++)
	fc->sound->Wave[V >> 4] += MMC5Sound.raw << 1;
  }

  void Do5PCMHQ() {
    uint32 V;  // mbg merge 7/17/06 made uint32
    if (!(MMC5Sound.rawcontrol & 0x40) && MMC5Sound.raw)
      for (V = MMC5Sound.BC[2]; V < fc->sound->SoundTS(); V++)
	fc->sound->WaveHi[V] += MMC5Sound.raw << 5;
    MMC5Sound.BC[2] = fc->sound->SoundTS();
  }

  void Mapper5_SW(DECLFW_ARGS) {
    A &= 0x1F;

    fc->sound->GameExpSound.Fill = [](FC *fc, int count) {
      ((MMC5*)fc->fceu->cartiface)->MMC5RunSound(count);
    };
    fc->sound->GameExpSound.HiFill = [](FC *fc) {
      ((MMC5*)fc->fceu->cartiface)->MMC5RunSoundHQ();
    };

    switch (A) {
      case 0x10:
	if (psfun != nullptr) (this->*psfun)();
	MMC5Sound.rawcontrol = V;
	break;
      case 0x11:
	if (psfun != nullptr) (this->*psfun)();
	MMC5Sound.raw = V;
	break;

      case 0x0:
      case 0x4:
	// printf("%04x:$%02x\n",A,V&0x30);
	if (sfun != nullptr) (this->*sfun)(A >> 2);
	MMC5Sound.env[A >> 2] = V;
	break;
      case 0x2:
      case 0x6:
	if (sfun != nullptr) (this->*sfun)(A >> 2);
	MMC5Sound.wl[A >> 2] &= ~0x00FF;
	MMC5Sound.wl[A >> 2] |= V & 0xFF;
	break;
      case 0x3:
      case 0x7:
	// printf("%04x:$%02x\n",A,V>>3);
	MMC5Sound.wl[A >> 2] &= ~0x0700;
	MMC5Sound.wl[A >> 2] |= (V & 0x07) << 8;
	MMC5Sound.running |= 1 << (A >> 2);
	break;
      case 0x15:
	if (sfun != nullptr) {
	  (this->*sfun)(0);
	  (this->*sfun)(1);
	}
	MMC5Sound.running &= V;
	MMC5Sound.enable = V;
	// printf("%02x\n",V);
	break;
    }
  }

  void Do5SQ(int P) {
    static constexpr int tal[4] = {1, 2, 4, 6};

    int32 start = MMC5Sound.BC[P];
    int32 end = (fc->sound->SoundTS() << 16) / fc->sound->soundtsinc;
    if (end <= start) return;
    MMC5Sound.BC[P] = end;

    int32 wl = MMC5Sound.wl[P] + 1;
    int32 amp = (MMC5Sound.env[P] & 0xF) << 4;
    int32 rthresh = tal[(MMC5Sound.env[P] & 0xC0) >> 6];

    if (wl >= 8 && (MMC5Sound.running & (P + 1))) {
      wl <<= 18;
      int dc = MMC5Sound.dcount[P];
      int vc = MMC5Sound.vcount[P];

      for (int32 V = start; V < end; V++) {
	if (dc < rthresh) fc->sound->Wave[V >> 4] += amp;
	vc -= fc->sound->nesincsize;
	while (vc <= 0) {
	  vc += wl;
	  dc = (dc + 1) & 7;
	}
      }
      MMC5Sound.dcount[P] = dc;
      MMC5Sound.vcount[P] = vc;
    }
  }

  void Do5SQHQ(int P) {
    static constexpr int tal[4] = {1, 2, 4, 6};

    int32 wl = MMC5Sound.wl[P] + 1;
    int32 amp = ((MMC5Sound.env[P] & 0xF) << 8);
    int32 rthresh = tal[(MMC5Sound.env[P] & 0xC0) >> 6];

    if (wl >= 8 && (MMC5Sound.running & (P + 1))) {
      wl <<= 1;

      int dc = MMC5Sound.dcount[P];
      int vc = MMC5Sound.vcount[P];
      for (uint32 V = MMC5Sound.BC[P]; V < fc->sound->SoundTS(); V++) {
	if (dc < rthresh) fc->sound->WaveHi[V] += amp;
	vc--;
	if (vc <= 0) {
	  // Less than zero when first started.
	  vc = wl;
	  dc = (dc + 1) & 7;
	}
      }
      MMC5Sound.dcount[P] = dc;
      MMC5Sound.vcount[P] = vc;
    }
    MMC5Sound.BC[P] = fc->sound->SoundTS();
  }

  void MMC5RunSoundHQ() {
    Do5SQHQ(0);
    Do5SQHQ(1);
    Do5PCMHQ();
  }

  void MMC5HiSync(int32 ts) {
    for (int x = 0; x < 3; x++) MMC5Sound.BC[x] = ts;
  }

  void MMC5RunSound(int Count) {
    Do5SQ(0);
    Do5SQ(1);
    Do5PCM();
    for (int x = 0; x < 3; x++) MMC5Sound.BC[x] = Count;
  }

  void Mapper5_ESI() {
    // It's weird that this reinstalls itself as a handler... -tom7
    fc->sound->GameExpSound.RChange = [](FC *fc) {
      ((MMC5*)fc->fceu->cartiface)->Mapper5_ESI();
    };
    if (FCEUS_SNDRATE) {
      if (FCEUS_SOUNDQ >= 1) {
	sfun = Do5SQHQ;
	psfun = Do5PCMHQ;
      } else {
	sfun = Do5SQ;
	psfun = Do5PCM;
      }
    } else {
      sfun = 0;
      psfun = 0;
    }
    memset(MMC5Sound.BC, 0, sizeof(MMC5Sound.BC));
    memset(MMC5Sound.vcount, 0, sizeof(MMC5Sound.vcount));
    fc->sound->GameExpSound.HiSync = [](FC *fc, int32 ts) {
      ((MMC5*)fc->fceu->cartiface)->MMC5HiSync(ts);
    };
  }

  // n.b. was called "Reset" in original code but installed
  // into the Power fn pointer. -tom7
  void Power() override {
    for (int x = 0; x < 4; x++) PRGBanks[x] = ~0;
    for (int x = 0; x < 8; x++) CHRBanksA[x] = ~0;
    for (int x = 0; x < 4; x++) CHRBanksB[x] = ~0;
    WRAMMaskEnable[0] = WRAMMaskEnable[1] = ~0;

    mmc5psize = mmc5vsize = 3;
    CHRMode = 0;

    NTAMirroring = NTFill = ATFill = 0xFF;

    MMC5Synco();

    fc->fceu->SetWriteHandler(0x4020, 0x5bff, [](DECLFW_ARGS) {
      ((MMC5*)fc->fceu->cartiface)->Mapper5_write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x4020, 0x5bff, [](DECLFR_ARGS) {
      return ((MMC5*)fc->fceu->cartiface)->MMC5_read(DECLFR_FORWARD);
    });

    fc->fceu->SetWriteHandler(0x5c00, 0x5fff, [](DECLFW_ARGS) {
      ((MMC5*)fc->fceu->cartiface)->MMC5_ExRAMWr(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x5c00, 0x5fff, [](DECLFR_ARGS) {
      return ((MMC5*)fc->fceu->cartiface)->MMC5_ExRAMRd(DECLFR_FORWARD);
    });

    fc->fceu->SetWriteHandler(0x6000, 0xFFFF, [](DECLFW_ARGS) {
      ((MMC5*)fc->fceu->cartiface)->MMC5_WriteROMRAM(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, [](DECLFR_ARGS) {
      return ((MMC5*)fc->fceu->cartiface)->MMC5_ReadROMRAM(DECLFR_FORWARD);
    });

    fc->fceu->SetWriteHandler(0x5000, 0x5015, [](DECLFW_ARGS) {
      ((MMC5*)fc->fceu->cartiface)->Mapper5_SW(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5205, 0x5206, [](DECLFW_ARGS) {
      ((MMC5*)fc->fceu->cartiface)->Mapper5_write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x5205, 0x5206, [](DECLFR_ARGS) {
      return ((MMC5*)fc->fceu->cartiface)->MMC5_read(DECLFR_FORWARD);
    });

    // GameHBIRQHook=MMC5_hb;
    // FCEU_CheatAddRAM(8,0x6000,WRAM);
    // FCEU_CheatAddRAM(1,0x5c00,ExRAM);
  }

  MMC5(FC *fc, CartInfo *info, int wsize, int battery) : CartInterface(fc) {
    if (wsize) {
      WRAM = (uint8 *)FCEU_gmalloc(wsize * 1024);
      fc->cart->SetupCartPRGMapping(0x10, WRAM, wsize * 1024, 1);
      // This was registered twice for some reason? (There's another
      // copy of this line unconditionally below.) -tom7
      // fc->state->AddExState(WRAM, wsize*1024, 0, "WRM5");
    }

    MMC5fill = (uint8 *)FCEU_gmalloc(1024);
    ExRAM = (uint8 *)FCEU_gmalloc(1024);

    fc->state->AddExVec({
	{PRGBanks, 4, "PRGB"},
	{CHRBanksA, 16, "CHRA"},
	{CHRBanksB, 8, "CHRB"},
	{&WRAMPage, 1, "WRMP"},
	{WRAMMaskEnable, 2, "WRME"},
	{&IRQScanline, 1, "IRQS"},
	{&IRQEnable, 1, "IRQE"},
	{&CHRMode, 1, "CHRM"},
	{&NTAMirroring, 1, "NTAM"},
	{&NTFill, 1, "NTFL"},
	{&ATFill, 1, "ATFL"},
	{&MMC5Sound.wl[0], 2 | FCEUSTATE_RLSB, "SDW0"},
	{&MMC5Sound.wl[1], 2 | FCEUSTATE_RLSB, "SDW1"},
	{MMC5Sound.env, 2, "SDEV"},
	{&MMC5Sound.enable, 1, "SDEN"},
	{&MMC5Sound.running, 1, "SDRU"},
	{&MMC5Sound.raw, 1, "SDRW"},
	{&MMC5Sound.rawcontrol, 1, "SDRC"},
        // Added by tom7 due to savestate divergence in Bandit Kings.
	{&mul, 2, "5mul"},
	// And Castlevania III.
	{&MMC5LineCounter, 1, "5lic"},
	{&MMC5IRQR, 1, "5irq"}});

    fc->state->AddExState(WRAM, wsize * 1024, 0, "WRAM");
    fc->state->AddExState(ExRAM, 1024, 0, "ERAM");
    // XXX perhaps these variables should be moved to here from PPU?
    fc->state->AddExState(&fc->ppu->mmc5ABMode, 1, 0, "ABMD"),
    fc->state->AddExState(&fc->ppu->MMC5HackSPMode, 1, 0, "SPLM");
    fc->state->AddExState(&fc->ppu->MMC5HackSPScroll, 1, 0, "SPLS");
    fc->state->AddExState(&fc->ppu->MMC5HackSPPage, 1, 0, "SPLP");
    fc->state->AddExState(&fc->ppu->MMC50x5130, 1, 0, "5130");

    MMC5WRAMsize = wsize / 8;
    BuildWRAMSizeTable();
    fc->fceu->GameStateRestore = MMC5_StateRestore;

    if (battery) {
      info->SaveGame[0] = WRAM;
      if (wsize <= 16)
	info->SaveGameLen[0] = 8192;
      else
	info->SaveGameLen[0] = 32768;
    }

    fc->ppu->MMC5HackVROMMask = fc->cart->CHRmask4[0];
    fc->ppu->MMC5HackExNTARAMPtr = ExRAM;
    fc->ppu->MMC5Hack = 1;
    fc->ppu->MMC5HackVROMPTR = fc->cart->CHRptr[0];
    fc->ppu->MMC5HackCHRMode = 0;
    fc->ppu->MMC5HackSPMode = 0;
    fc->ppu->MMC5HackSPScroll = 0;
    fc->ppu->MMC5HackSPPage = 0;

    Mapper5_ESI();
  }
};
}

CartInterface *Mapper5_Init(FC *fc, CartInfo *info) {
  return new MMC5(fc, info, DetectMMC5WRAMSize(info->CRC32), info->battery);
}

// Here are some contradictory comments I found. -tom7

// ELROM seems to have 8KB of RAM
// ETROM seems to have 16KB of WRAM
// EWROM seems to have 32KB of WRAM

// ELROM seems to have 0KB of WRAM
// EKROM seems to have 8KB of WRAM
// ETROM seems to have 16KB of WRAM
// EWROM seems to have 32KB of WRAM

// ETROM and EWROM are battery-backed, EKROM isn't.

CartInterface *ETROM_Init(FC *fc, CartInfo *info) {
  return new MMC5(fc, info, 16, info->battery);
}

CartInterface *ELROM_Init(FC *fc, CartInfo *info) {
  return new MMC5(fc, info, 0, 0);
}

CartInterface *EWROM_Init(FC *fc, CartInfo *info) {
  return new MMC5(fc, info, 32, info->battery);
}

CartInterface *EKROM_Init(FC *fc, CartInfo *info) {
  return new MMC5(fc, info, 8, info->battery);
}
