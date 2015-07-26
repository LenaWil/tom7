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

#define vrctemp mapbyte1[0]
static uint8 indox;

#include "emu2413.h"

static int acount = 0;

static OPLL *VRC7Sound = nullptr;
static int dwave = 0;

void DoVRC7Sound() {
  int32 z, a;

  if (FCEUS_SOUNDQ >= 1) return;
  z = ((fceulib__.sound->SoundTS() << 16) / fceulib__.sound->soundtsinc) >> 4;
  a = z - dwave;

  OPLL_FillBuffer(VRC7Sound, &fceulib__.sound->Wave[dwave], a, 1);

  dwave += a;
}

void UpdateOPLNEO(FC *fc, int32 *Wave, int Count) {
  OPLL_FillBuffer(VRC7Sound, Wave, Count, 4);
}

void UpdateOPL(FC *fc, int Count) {
  int32 z, a;

  z = ((fc->sound->SoundTS() << 16) / fc->sound->soundtsinc) >> 4;
  a = z - dwave;

  if (VRC7Sound && a)
    OPLL_FillBuffer(VRC7Sound, &fc->sound->Wave[dwave], a, 1);

  dwave = 0;
}

static inline void DaMirror(int V) {
  int salpo[4] = {MI_V, MI_H, MI_0, MI_1};
  fceulib__.cart->setmirror(salpo[V & 3]);
}

DECLFW(Mapper85_write) {
  A |= (A & 8) << 1;

  if (A >= 0xa000 && A <= 0xDFFF) {
    // printf("$%04x, $%04x\n",fceulib__.X->PC,A);
    A &= 0xF010;
    {
      int x = ((A >> 4) & 1) | ((A - 0xA000) >> 11);
      mapbyte3[x] = V;
      fceulib__.cart->setchr1(x << 10, V);
    }
  } else if (A == 0x9030) {
    if (FCEUS_SNDRATE) {
      OPLL_writeReg(VRC7Sound, indox, V);
      fceulib__.sound->GameExpSound.Fill = UpdateOPL;
      fceulib__.sound->GameExpSound.NeoFill = UpdateOPLNEO;
    }
  } else {
    switch (A & 0xF010) {
      case 0x8000:
        mapbyte2[0] = V;
        fceulib__.cart->setprg8(0x8000, V);
        break;
      case 0x8010:
        mapbyte2[1] = V;
        fceulib__.cart->setprg8(0xa000, V);
        break;
      case 0x9000:
        mapbyte2[2] = V;
        fceulib__.cart->setprg8(0xc000, V);
        break;
      case 0x9010: indox = V; break;
      case 0xe000:
        mapbyte2[3] = V;
        DaMirror(V);
        break;
      case 0xE010:
        fceulib__.ines->iNESIRQLatch = V;
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        break;
      case 0xF000:
        fceulib__.ines->iNESIRQa = V & 2;
        vrctemp = V & 1;
        if (V & 2) {
          fceulib__.ines->iNESIRQCount = fceulib__.ines->iNESIRQLatch;
        }
        acount = 0;
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        break;
      case 0xf010:
        if (vrctemp)
          fceulib__.ines->iNESIRQa = 1;
        else
          fceulib__.ines->iNESIRQa = 0;
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        break;
    }
  }
}

static void KonamiIRQHook(FC *fc, int a) {
#define ACBOO 341
  //  #define ACBOO ((227*2)+1)
  if (fceulib__.ines->iNESIRQa) {
    acount += a * 3;

    if (acount >= ACBOO) {
    doagainbub:
      acount -= ACBOO;
      fceulib__.ines->iNESIRQCount++;
      if (fceulib__.ines->iNESIRQCount & 0x100) {
        fceulib__.X->IRQBegin(FCEU_IQEXT);
        fceulib__.ines->iNESIRQCount = fceulib__.ines->iNESIRQLatch;
      }
      if (acount >= ACBOO) goto doagainbub;
    }
  }
}

void Mapper85_StateRestore(FC *fc, int version) {

  if (version < 7200) {
    for (int x = 0; x < 8; x++)
      mapbyte3[x] = fc->ines->iNESCHRBankList[x];
    for (int x = 0; x < 3; x++) mapbyte2[x] = PRGBankList[x];
    mapbyte2[3] = (fc->ines->iNESMirroring < 0x10) ?
                      fc->ines->iNESMirroring :
                      fc->ines->iNESMirroring - 0xE;
  }

  for (int x = 0; x < 8; x++) fc->cart->setchr1(x * 0x400, mapbyte3[x]);
  for (int x = 0; x < 3; x++)
    fc->cart->setprg8(0x8000 + x * 8192, mapbyte2[x]);
  DaMirror(mapbyte2[3]);
  // LoadOPL();
}

static void M85SC(FC *fc) {
  if (VRC7Sound) OPLL_set_rate(VRC7Sound, FCEUS_SNDRATE);
}

static void M85SKill(FC *fc) {
  if (VRC7Sound) OPLL_delete(VRC7Sound);
  VRC7Sound = nullptr;
}

static void VRC7SI() {
  fceulib__.sound->GameExpSound.RChange = M85SC;
  fceulib__.sound->GameExpSound.Kill = M85SKill;

  VRC7Sound = OPLL_new(3579545, FCEUS_SNDRATE ? FCEUS_SNDRATE : 44100);
  OPLL_reset(VRC7Sound);
  OPLL_reset(VRC7Sound);
}

void NSFVRC7_Init() {
  fceulib__.fceu->SetWriteHandler(0x9010, 0x901F, Mapper85_write);
  fceulib__.fceu->SetWriteHandler(0x9030, 0x903F, Mapper85_write);
  VRC7SI();
}

void Mapper85_init() {
  fceulib__.X->MapIRQHook = KonamiIRQHook;
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, Mapper85_write);
  fceulib__.fceu->GameStateRestore = Mapper85_StateRestore;
  if (!fceulib__.ines->VROM_size)
    fceulib__.cart->SetupCartCHRMapping(0, CHRRAM, 8192, 1);
  // AddExState(VRC7Instrument, 16, 0, "VC7I");
  // AddExState(VRC7Chan, sizeof(VRC7Chan), 0, "V7CH");
  VRC7SI();
}
