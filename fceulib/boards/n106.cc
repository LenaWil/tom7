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

static constexpr int TOINDEX = 16 + 1;

namespace {
struct N106 : public CartInterface {
  uint16 IRQCount = 0;
  uint8 IRQa = 0;

  uint8 WRAM[8192] = {};
  uint8 IRAM[128] = {};

  DECLFR_RET AWRAM(DECLFR_ARGS) {
    return WRAM[A - 0x6000];
  }

  void BWRAM(DECLFW_ARGS) {
    WRAM[A - 0x6000] = V;
  }

  uint8 NTAPage[4] = {};

  uint8 dopol = 0;
  uint8 gorfus = 0;
  uint8 gorko = 0;

  bool is210 = false; /* Lesser mapper. */

  uint8 PRG[3] = {};
  uint8 CHR[8] = {};

  bool battery = 0;

  const vector<SFORMAT> N106_StateRegs;

  void SyncPRG() {
    fc->cart->setprg8(0x8000, PRG[0]);
    fc->cart->setprg8(0xa000, PRG[1]);
    fc->cart->setprg8(0xc000, PRG[2]);
    fc->cart->setprg8(0xe000, 0x3F);
  }

  void NamcoIRQHook(int a) {
    if (IRQa) {
      IRQCount += a;
      if (IRQCount >= 0x7FFF) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
	IRQCount = 0x7FFF;  // 7FFF;
      }
    }
  }

  DECLFR_RET Namco_Read4800(DECLFR_ARGS) {
    uint8 ret = IRAM[dopol & 0x7f];
    /* Maybe I should call NamcoSoundHack() here? */
    if (dopol & 0x80) dopol = (dopol & 0x80) | ((dopol + 1) & 0x7f);
    return ret;
  }

  DECLFR_RET Namco_Read5000(DECLFR_ARGS) {
    return IRQCount;
  }

  DECLFR_RET Namco_Read5800(DECLFR_ARGS) {
    return IRQCount >> 8;
  }

  void DoNTARAMROM(int w, uint8 V) {
    NTAPage[w] = V;
    if (V >= 0xE0) {
      fc->cart->setntamem(fc->ppu->NTARAM + ((V & 1) << 10), 1, w);
    } else {
      V &= fc->cart->CHRmask1[0];
      fc->cart->setntamem(fc->cart->CHRptr[0] + (V << 10), 0, w);
    }
  }

  void FixNTAR() {
    for (int x = 0; x < 4; x++) DoNTARAMROM(x, NTAPage[x]);
  }

  void DoCHRRAMROM(int x, uint8 V) {
    CHR[x] = V;
    if (!is210 && !((gorfus >> ((x >> 2) + 6)) & 1) && (V >= 0xE0)) {
      // printf("BLAHAHA: %d, %02x\n",x,V);
      // setchr1r(0x10,x<<10,V&7);
    } else
      fc->cart->setchr1(x << 10, V);
  }

  void FixCRR() {
    for (int x = 0; x < 8; x++) DoCHRRAMROM(x, CHR[x]);
  }

  void Mapper19C0D8_write(DECLFW_ARGS) {
    DoNTARAMROM((A - 0xC000) >> 11, V);
  }

  uint32 FreqCache[8] = {};
  uint32 EnvCache[8] = {};
  uint32 LengthCache[8] = {};

  void FixCache(int a, int V) {
    int w = (a >> 3) & 0x7;
    switch (a & 0x07) {
      case 0x00:
	FreqCache[w] &= ~0x000000FF;
	FreqCache[w] |= V;
	break;
      case 0x02:
	FreqCache[w] &= ~0x0000FF00;
	FreqCache[w] |= V << 8;
	break;
      case 0x04:
	FreqCache[w] &= ~0x00030000;
	FreqCache[w] |= (V & 3) << 16;
	LengthCache[w] = (8 - ((V >> 2) & 7)) << 2;
	break;
      case 0x07: EnvCache[w] = (double)(V & 0xF) * 576716; break;
    }
  }

  void Mapper19_write(DECLFW_ARGS) {
    A &= 0xF800;
    if (A >= 0x8000 && A <= 0xb800)
      DoCHRRAMROM((A - 0x8000) >> 11, V);
    else
      switch (A) {
	case 0x4800:
	  if (dopol & 0x40) {
	    if (FCEUS_SNDRATE) {
	      NamcoSoundHack();
	      fc->sound->GameExpSound.Fill = [](FC *fc, int c) {
		((N106 *)fc->fceu->cartiface)->NamcoSound(c);
	      };
	      fc->sound->GameExpSound.HiFill = [](FC *fc) {
		((N106 *)fc->fceu->cartiface)->DoNamcoSoundHQ();
	      };
	      fc->sound->GameExpSound.HiSync = [](FC *fc, int32 i) {
		((N106 *)fc->fceu->cartiface)->SyncHQ(i);
	      };
	    }
	    FixCache(dopol, V);
	  }
	  IRAM[dopol & 0x7f] = V;
	  if (dopol & 0x80) dopol = (dopol & 0x80) | ((dopol + 1) & 0x7f);
	  break;
	case 0xf800: dopol = V; break;
	case 0x5000:
	  IRQCount &= 0xFF00;
	  IRQCount |= V;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0x5800:
	  IRQCount &= 0x00ff;
	  IRQCount |= (V & 0x7F) << 8;
	  IRQa = V & 0x80;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0xE000:
	  gorko = V & 0xC0;
	  PRG[0] = V & 0x3F;
	  SyncPRG();
	  break;
	case 0xE800:
	  gorfus = V & 0xC0;
	  FixCRR();
	  PRG[1] = V & 0x3F;
	  SyncPRG();
	  break;
	case 0xF000:
	  PRG[2] = V & 0x3F;
	  SyncPRG();
	  break;
      }
  }

  int dwave = 0;

  void NamcoSoundHack() {
    int32 z, a;
    if (FCEUS_SOUNDQ >= 1) {
      DoNamcoSoundHQ();
      return;
    }
    z = ((fc->sound->SoundTS() << 16) / fc->sound->soundtsinc) >> 4;
    a = z - dwave;
    if (a) DoNamcoSound(&fc->sound->Wave[dwave], a);
    dwave += a;
  }

  void NamcoSound(int Count) {
    int32 z, a;
    z = ((fc->sound->SoundTS() << 16) / fc->sound->soundtsinc) >> 4;
    a = z - dwave;
    if (a) DoNamcoSound(&fc->sound->Wave[dwave], a);
    dwave = 0;
  }

  uint32 PlayIndex[8] = {};
  int32 vcount[8] = {};
  int32 CVBC = 0;

  // 16:15
  void SyncHQ(int32 ts) {
    CVBC = ts;
  }

  /* Things to do:
	  1        Read freq low
	  2        Read freq mid
	  3        Read freq high
	  4        Read envelope
	  ...?
  */

  inline uint32 FetchDuff(uint32 P, uint32 envelope) {
    uint32 duff = 
      IRAM[((IRAM[0x46 + (P << 3)] + (PlayIndex[P] >> TOINDEX)) & 0xFF) >> 1];
    if ((IRAM[0x46 + (P << 3)] + (PlayIndex[P] >> TOINDEX)) & 1) duff >>= 4;
    duff &= 0xF;
    duff = (duff * envelope) >> 16;
    return duff;
  }

  void DoNamcoSoundHQ() {
    const int32 cyclesuck = (((IRAM[0x7F] >> 4) & 7) + 1) * 15;

    for (int32 P = 7; P >= (7 - ((IRAM[0x7F] >> 4) & 7)); P--) {
      if ((IRAM[0x44 + (P << 3)] & 0xE0) && (IRAM[0x47 + (P << 3)] & 0xF)) {
	uint32 freq;
	int32 vco;
	uint32 duff2, lengo, envelope;

	vco = vcount[P];
	freq = FreqCache[P];
	envelope = EnvCache[P];
	lengo = LengthCache[P];

	duff2 = FetchDuff(P, envelope);
	for (uint32 V = CVBC << 1; V < fc->sound->SoundTS() << 1; V++) {
	  fc->sound->WaveHi[V >> 1] += duff2;
	  if (!vco) {
	    PlayIndex[P] += freq;
	    while ((PlayIndex[P] >> TOINDEX) >= lengo)
	      PlayIndex[P] -= lengo << TOINDEX;
	    duff2 = FetchDuff(P, envelope);
	    vco = cyclesuck;
	  }
	  vco--;
	}
	vcount[P] = vco;
      }
    }
    CVBC = fc->sound->SoundTS();
  }

  void DoNamcoSound(int32 *Wave, int Count) {
    for (int P = 7; P >= 7 - ((IRAM[0x7F] >> 4) & 7); P--) {
      if ((IRAM[0x44 + (P << 3)] & 0xE0) && (IRAM[0x47 + (P << 3)] & 0xF)) {
	int32 inc;
	uint32 freq;
	int32 vco;
	uint32 duff, duff2, lengo, envelope;

	vco = vcount[P];
	freq = FreqCache[P];
	envelope = EnvCache[P];
	lengo = LengthCache[P];

	if (!freq) { /*printf("Ack");*/
	  continue;
	}

	{
	  const int c = ((IRAM[0x7F] >> 4) & 7) + 1;
	  inc = (long double)(FCEUS_SNDRATE << 15) /
		((long double)freq * 21477272 /
		 ((long double)0x400000 * c * 45));
	}

	duff = IRAM[(((IRAM[0x46 + (P << 3)] + PlayIndex[P]) & 0xFF) >> 1)];
	if ((IRAM[0x46 + (P << 3)] + PlayIndex[P]) & 1) duff >>= 4;
	duff &= 0xF;
	duff2 = (duff * envelope) >> 19;
	for (int V = 0; V < Count * 16; V++) {
	  if (vco >= inc) {
	    PlayIndex[P]++;
	    if (PlayIndex[P] >= lengo) PlayIndex[P] = 0;
	    vco -= inc;
	    duff = IRAM[(((IRAM[0x46 + (P << 3)] + PlayIndex[P]) & 0xFF) >> 1)];
	    if ((IRAM[0x46 + (P << 3)] + PlayIndex[P]) & 1) duff >>= 4;
	    duff &= 0xF;
	    duff2 = (duff * envelope) >> 19;
	  }
	  Wave[V >> 4] += duff2;
	  vco += 0x8000;
	}
	vcount[P] = vco;
      }
    }
  }
 
  void M19SC() {
    if (FCEUS_SNDRATE) Mapper19_ESI();
  }

  void Mapper19_ESI() {
    fc->sound->GameExpSound.RChange = [](FC *fc) {
      ((N106 *)fc->fceu->cartiface)->M19SC();
    };
    memset(vcount, 0, sizeof(vcount));
    memset(PlayIndex, 0, sizeof(PlayIndex));
    CVBC = 0;
  }

  void Power() override {
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
      ((N106*)fc->fceu->cartiface)->Mapper19_write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4020, 0x5fff, [](DECLFW_ARGS) {
      ((N106*)fc->fceu->cartiface)->Mapper19_write(DECLFW_FORWARD);
    });
    if (!is210) {
      fc->fceu->SetWriteHandler(0xc000, 0xdfff, [](DECLFW_ARGS) {
	((N106*)fc->fceu->cartiface)->Mapper19C0D8_write(DECLFW_FORWARD);
      });
      fc->fceu->SetReadHandler(0x4800, 0x4fff, [](DECLFR_ARGS) {
	return ((N106*)fc->fceu->cartiface)->
	  Namco_Read4800(DECLFR_FORWARD);
      });
      fc->fceu->SetReadHandler(0x5000, 0x57ff, [](DECLFR_ARGS) {
	return ((N106*)fc->fceu->cartiface)->
	  Namco_Read5000(DECLFR_FORWARD);
      });
      fc->fceu->SetReadHandler(0x5800, 0x5fff, [](DECLFR_ARGS) {
	return ((N106*)fc->fceu->cartiface)->
	  Namco_Read5800(DECLFR_FORWARD);
      });
      NTAPage[0] = NTAPage[1] = NTAPage[2] = NTAPage[3] = 0xFF;
      FixNTAR();
    }

    fc->fceu->SetReadHandler(0x6000, 0x7FFF, [](DECLFR_ARGS) {
      return ((N106*)fc->fceu->cartiface)->AWRAM(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      ((N106*)fc->fceu->cartiface)->BWRAM(DECLFW_FORWARD);
    });
    // FCEU_CheatAddRAM(8,0x6000,WRAM);

    gorfus = 0xFF;
    SyncPRG();
    FixCRR();

    if (!battery) {
      FCEU_dwmemset(WRAM, 0, 8192);
      FCEU_dwmemset(IRAM, 0, 128);
    }
    for (int x = 0x40; x < 0x80; x++) FixCache(x, IRAM[x]);
  }

  N106(FC *fc, CartInfo *info) : CartInterface(fc),
				 N106_StateRegs{{PRG, 3, "PRG0"},
                                                {CHR, 8, "CHR0"},
						{NTAPage, 4, "NTA0"}} {
    
  }
};

// XXX excise nsf code?
struct NSFN106 : public N106 {
  NSFN106(FC *fc, CartInfo *info) : N106(fc, info) {
    fc->fceu->SetWriteHandler(0xf800, 0xffff, [](DECLFW_ARGS) {
      ((NSFN106*)fc->fceu->cartiface)->Mapper19_write(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4800, 0x4fff, [](DECLFW_ARGS) {
      ((NSFN106*)fc->fceu->cartiface)->Mapper19_write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x4800, 0x4fff, [](DECLFR_ARGS) {
      return ((NSFN106*)fc->fceu->cartiface)->
	Namco_Read4800(DECLFR_FORWARD);
    });
    Mapper19_ESI();
  }
};

struct Mapper19 : public N106 {
  void Mapper19_StateRestore() {
    SyncPRG();
    FixNTAR();
    FixCRR();
    for (int x = 0x40; x < 0x80; x++) FixCache(x, IRAM[x]);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper19 *)fc->fceu->cartiface)->Mapper19_StateRestore();
  }

  Mapper19(FC *fc, CartInfo *info) : N106(fc, info) {
    is210 = 0;
    battery = info->battery;

    fc->X->MapIRQHook = [](FC *fc, int a) {
      return ((Mapper19 *)fc->fceu->cartiface)->NamcoIRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->sound->GameExpSound.RChange = [](FC *fc) {
      return ((Mapper19 *)fc->fceu->cartiface)->M19SC();
    };

    if (FCEUS_SNDRATE) Mapper19_ESI();

    fc->state->AddExState(WRAM, 8192, 0, "WRAM");
    fc->state->AddExState(IRAM, 128, 0, "IRAM");
    fc->state->AddExVec(N106_StateRegs);

    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = 8192;
      info->SaveGame[1] = IRAM;
      info->SaveGameLen[1] = 128;
    }
  }
};

struct Mapper210 : public N106 {
  void Mapper210_StateRestore() {
    SyncPRG();
    FixCRR();
  }
  
  Mapper210(FC *fc, CartInfo *info) : N106(fc, info) {
    is210 = 1;
    fc->fceu->GameStateRestore = [](FC *fc, int version) {
      ((Mapper210 *)fc->fceu->cartiface)->Mapper210_StateRestore();
    };
    fc->state->AddExState(WRAM, 8192, 0, "WRAM");
    fc->state->AddExVec(N106_StateRegs);
  }
};

}

CartInterface *NSFN106_Init(FC *fc, CartInfo *info) {
  return new NSFN106(fc, info);
}

CartInterface *Mapper19_Init(FC *fc, CartInfo *info) {
  return new Mapper19(fc, info);
}

CartInterface *Mapper210_Init(FC *fc, CartInfo *info) {
  return new Mapper210(fc, info);
}
