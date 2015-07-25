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

static uint16 IRQCount;
static uint8 IRQa;

static uint8 WRAM[8192];
static uint8 IRAM[128];

static DECLFR(AWRAM) {
  return (WRAM[A - 0x6000]);
}

static DECLFW(BWRAM) {
  WRAM[A - 0x6000] = V;
}

static void Mapper19_ESI(FC *fc);

static uint8 NTAPage[4];

static uint8 dopol;
static uint8 gorfus;
static uint8 gorko;

static void NamcoSound(FC *fc, int Count);
static void NamcoSoundHack();
static void DoNamcoSound(int32 *Wave, int Count);
static void DoNamcoSoundHQ(FC *fc);
static void SyncHQ(FC *fc, int32 ts);

static int is210; /* Lesser mapper. */

static uint8 PRG[3];
static uint8 CHR[8];

static int battery = 0;

static SFORMAT N106_StateRegs[] = {
    {PRG, 3, "PRG"}, {CHR, 8, "CHR"}, {NTAPage, 4, "NTA"}, {0}};

static void SyncPRG() {
  fceulib__.cart->setprg8(0x8000, PRG[0]);
  fceulib__.cart->setprg8(0xa000, PRG[1]);
  fceulib__.cart->setprg8(0xc000, PRG[2]);
  fceulib__.cart->setprg8(0xe000, 0x3F);
}

static void NamcoIRQHook(int a) {
  if (IRQa) {
    IRQCount += a;
    if (IRQCount >= 0x7FFF) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      IRQa = 0;
      IRQCount = 0x7FFF;  // 7FFF;
    }
  }
}

static DECLFR(Namco_Read4800) {
  uint8 ret = IRAM[dopol & 0x7f];
  /* Maybe I should call NamcoSoundHack() here? */
  if (dopol & 0x80) dopol = (dopol & 0x80) | ((dopol + 1) & 0x7f);
  return ret;
}

static DECLFR(Namco_Read5000) {
  return IRQCount;
}

static DECLFR(Namco_Read5800) {
  return IRQCount >> 8;
}

static void DoNTARAMROM(int w, uint8 V) {
  NTAPage[w] = V;
  if (V >= 0xE0) {
    fceulib__.cart->setntamem(fceulib__.ppu->NTARAM + ((V & 1) << 10), 1, w);
  } else {
    V &= fceulib__.cart->CHRmask1[0];
    fceulib__.cart->setntamem(fceulib__.cart->CHRptr[0] + (V << 10), 0, w);
  }
}

static void FixNTAR() {
  for (int x = 0; x < 4; x++) DoNTARAMROM(x, NTAPage[x]);
}

static void DoCHRRAMROM(int x, uint8 V) {
  CHR[x] = V;
  if (!is210 && !((gorfus >> ((x >> 2) + 6)) & 1) && (V >= 0xE0)) {
    // printf("BLAHAHA: %d, %02x\n",x,V);
    // setchr1r(0x10,x<<10,V&7);
  } else
    fceulib__.cart->setchr1(x << 10, V);
}

static void FixCRR() {
  for (int x = 0; x < 8; x++) DoCHRRAMROM(x, CHR[x]);
}

static DECLFW(Mapper19C0D8_write) {
  DoNTARAMROM((A - 0xC000) >> 11, V);
}

static uint32 FreqCache[8];
static uint32 EnvCache[8];
static uint32 LengthCache[8];

static void FixCache(int a, int V) {
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

static DECLFW(Mapper19_write) {
  A &= 0xF800;
  if (A >= 0x8000 && A <= 0xb800)
    DoCHRRAMROM((A - 0x8000) >> 11, V);
  else
    switch (A) {
      case 0x4800:
        if (dopol & 0x40) {
          if (FCEUS_SNDRATE) {
            NamcoSoundHack();
            fceulib__.sound->GameExpSound.Fill = NamcoSound;
            fceulib__.sound->GameExpSound.HiFill = DoNamcoSoundHQ;
            fceulib__.sound->GameExpSound.HiSync = SyncHQ;
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
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        break;
      case 0x5800:
        IRQCount &= 0x00ff;
        IRQCount |= (V & 0x7F) << 8;
        IRQa = V & 0x80;
        fceulib__.X->IRQEnd(FCEU_IQEXT);
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

static int dwave = 0;

static void NamcoSoundHack() {
  int32 z, a;
  if (FCEUS_SOUNDQ >= 1) {
    DoNamcoSoundHQ(&fceulib__);
    return;
  }
  z = ((fceulib__.sound->SoundTS() << 16) / fceulib__.sound->soundtsinc) >> 4;
  a = z - dwave;
  if (a) DoNamcoSound(&fceulib__.sound->Wave[dwave], a);
  dwave += a;
}

static void NamcoSound(FC *fc, int Count) {
  int32 z, a;
  z = ((fceulib__.sound->SoundTS() << 16) / fceulib__.sound->soundtsinc) >> 4;
  a = z - dwave;
  if (a) DoNamcoSound(&fc->sound->Wave[dwave], a);
  dwave = 0;
}

static uint32 PlayIndex[8];
static int32 vcount[8];
static int32 CVBC;

static constexpr int TOINDEX = 16 + 1;

// 16:15
static void SyncHQ(FC *fc, int32 ts) {
  CVBC = ts;
}

/* Things to do:
        1        Read freq low
        2        Read freq mid
        3        Read freq high
        4        Read envelope
        ...?
*/

static inline uint32 FetchDuff(uint32 P, uint32 envelope) {
  uint32 duff;
  duff =
      IRAM[((IRAM[0x46 + (P << 3)] + (PlayIndex[P] >> TOINDEX)) & 0xFF) >> 1];
  if ((IRAM[0x46 + (P << 3)] + (PlayIndex[P] >> TOINDEX)) & 1) duff >>= 4;
  duff &= 0xF;
  duff = (duff * envelope) >> 16;
  return (duff);
}

static void DoNamcoSoundHQ(FC *fc) {
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
      for (uint32 V = CVBC << 1; V < fceulib__.sound->SoundTS() << 1; V++) {
        fceulib__.sound->WaveHi[V >> 1] += duff2;
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
  CVBC = fceulib__.sound->SoundTS();
}

static void DoNamcoSound(int32 *Wave, int Count) {
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
        int c = ((IRAM[0x7F] >> 4) & 7) + 1;
        inc = (long double)(FCEUS_SNDRATE << 15) /
              ((long double)freq * 21477272 / ((long double)0x400000 * c * 45));
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

static void Mapper19_StateRestore(FC *fc, int version) {
  SyncPRG();
  FixNTAR();
  FixCRR();
  for (int x = 0x40; x < 0x80; x++) FixCache(x, IRAM[x]);
}

static void M19SC(FC *fc) {
  if (FCEUS_SNDRATE) Mapper19_ESI(fc);
}

static void Mapper19_ESI(FC *fc) {
  fc->sound->GameExpSound.RChange = M19SC;
  memset(vcount, 0, sizeof(vcount));
  memset(PlayIndex, 0, sizeof(PlayIndex));
  CVBC = 0;
}

void NSFN106_Init() {
  fceulib__.fceu->SetWriteHandler(0xf800, 0xffff, Mapper19_write);
  fceulib__.fceu->SetWriteHandler(0x4800, 0x4fff, Mapper19_write);
  fceulib__.fceu->SetReadHandler(0x4800, 0x4fff, Namco_Read4800);
  Mapper19_ESI(&fceulib__);
}

static void N106_Power(FC *fc) {
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, Mapper19_write);
  fceulib__.fceu->SetWriteHandler(0x4020, 0x5fff, Mapper19_write);
  if (!is210) {
    fceulib__.fceu->SetWriteHandler(0xc000, 0xdfff, Mapper19C0D8_write);
    fceulib__.fceu->SetReadHandler(0x4800, 0x4fff, Namco_Read4800);
    fceulib__.fceu->SetReadHandler(0x5000, 0x57ff, Namco_Read5000);
    fceulib__.fceu->SetReadHandler(0x5800, 0x5fff, Namco_Read5800);
    NTAPage[0] = NTAPage[1] = NTAPage[2] = NTAPage[3] = 0xFF;
    FixNTAR();
  }

  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, AWRAM);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, BWRAM);
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

void Mapper19_Init(CartInfo *info) {
  is210 = 0;
  battery = info->battery;
  info->Power = N106_Power;

  fceulib__.X->MapIRQHook = NamcoIRQHook;
  fceulib__.fceu->GameStateRestore = Mapper19_StateRestore;
  fceulib__.sound->GameExpSound.RChange = M19SC;

  if (FCEUS_SNDRATE) Mapper19_ESI(&fceulib__);

  fceulib__.state->AddExState(WRAM, 8192, 0, "WRAM");
  fceulib__.state->AddExState(IRAM, 128, 0, "IRAM");
  fceulib__.state->AddExState(N106_StateRegs, ~0, 0, 0);

  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = 8192;
    info->SaveGame[1] = IRAM;
    info->SaveGameLen[1] = 128;
  }
}

static void Mapper210_StateRestore(FC *fc, int version) {
  SyncPRG();
  FixCRR();
}

void Mapper210_Init(CartInfo *info) {
  is210 = 1;
  fceulib__.fceu->GameStateRestore = Mapper210_StateRestore;
  info->Power = N106_Power;
  fceulib__.state->AddExState(WRAM, 8192, 0, "WRAM");
  fceulib__.state->AddExState(N106_StateRegs, ~0, 0, 0);
}
