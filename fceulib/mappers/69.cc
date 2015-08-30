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

static void AYSound(FC *fc, int Count);
static void AYSoundHQ(FC *fc);
static void DoAYSQ(int x);
static void DoAYSQHQ(int x);

static uint8 sunindex;

#define sunselect GMB_mapbyte1(fc)[0]
#define sungah GMB_mapbyte1(fc)[1]

static DECLFW(SUN5BWRAM) {
  if ((sungah & 0xC0) == 0xC0) (GMB_WRAM(fc) - 0x6000)[A] = V;
}

static DECLFR(SUN5AWRAM) {
  if ((sungah & 0xC0) == 0x40) return fceulib__.X->DB;
  return Cart::CartBROB(DECLFR_FORWARD);
}

static DECLFW(Mapper69_SWL) {
  sunindex = V % 14;
}

static DECLFW(Mapper69_SWH) {
  fceulib__.sound->GameExpSound.Fill = AYSound;
  fceulib__.sound->GameExpSound.HiFill = AYSoundHQ;
  if (FCEUS_SNDRATE) switch (sunindex) {
      case 0:
      case 1:
      case 8:
        if (FCEUS_SOUNDQ >= 1)
          DoAYSQHQ(0);
        else
          DoAYSQ(0);
        break;
      case 2:
      case 3:
      case 9:
        if (FCEUS_SOUNDQ >= 1)
          DoAYSQHQ(1);
        else
          DoAYSQ(1);
        break;
      case 4:
      case 5:
      case 10:
        if (FCEUS_SOUNDQ >= 1)
          DoAYSQHQ(2);
        else
          DoAYSQ(2);
        break;
      case 7:
        for (int x = 0; x < 2; x++)
          if (FCEUS_SOUNDQ >= 1)
            DoAYSQHQ(x);
          else
            DoAYSQ(x);
        break;
    }
  GMB_MapperExRAM(fc)[sunindex] = V;
}

static DECLFW(Mapper69_write) {
  switch (A & 0xE000) {
  case 0x8000: sunselect = V; break;
  case 0xa000:
    sunselect &= 0xF;
    if (sunselect <= 7)
      VROM_BANK1(fc, sunselect << 10, V);
    else
      switch (sunselect & 0x0f) {
      case 8:
	sungah = V;
	if (V & 0x40) {
	  if (V & 0x80) {
	    // Select WRAM
	    fceulib__.cart->setprg8r(0x10, 0x6000, 0);
	  }
	} else {
	  fceulib__.cart->setprg8(0x6000, V);
	}
	break;
      case 9: ROM_BANK8(fc, 0x8000, V); break;
      case 0xa: ROM_BANK8(fc, 0xa000, V); break;
      case 0xb: ROM_BANK8(fc, 0xc000, V); break;
      case 0xc:
	switch (V & 3) {
	case 0: fceulib__.ines->MIRROR_SET2(1); break;
	case 1: fceulib__.ines->MIRROR_SET2(0); break;
	case 2: fceulib__.ines->onemir(0); break;
	case 3: fceulib__.ines->onemir(1); break;
	}
	break;
      case 0xd:
	fceulib__.ines->iNESIRQa = V;
	fceulib__.X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xe:
	fceulib__.ines->iNESIRQCount &= 0xFF00;
	fceulib__.ines->iNESIRQCount |= V;
	fceulib__.X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xf:
	fceulib__.ines->iNESIRQCount &= 0x00FF;
	fceulib__.ines->iNESIRQCount |= V << 8;
	fceulib__.X->IRQEnd(FCEU_IQEXT);
	break;
      }
    break;
  }
}

static int32 vcount[3];
static int32 dcount[3];
static int CAYBC[3];

static void DoAYSQ(int x) {
  FC *fc = &fceulib__;
  int32 freq =
    ((GMB_MapperExRAM(fc)[x << 1] |
      ((GMB_MapperExRAM(fc)[(x << 1) + 1] & 15) << 8)) + 1)
    << (4 + 17);
  int32 amp = (GMB_MapperExRAM(fc)[0x8 + x] & 15) << 2;
  int32 start, end;

  amp += amp >> 1;

  start = CAYBC[x];
  end = (fceulib__.sound->SoundTS() << 16) / fceulib__.sound->soundtsinc;
  if (end <= start) return;
  CAYBC[x] = end;

  if (amp) {
    for (int V = start; V < end; V++) {
      if (dcount[x]) fceulib__.sound->Wave[V >> 4] += amp;
      vcount[x] -= fceulib__.sound->nesincsize;
      while (vcount[x] <= 0) {
        dcount[x] ^= 1;
        vcount[x] += freq;
      }
    }
  }
}

static void DoAYSQHQ(int x) {
  FC *fc = &fceulib__;
  int32 freq =
    ((GMB_MapperExRAM(fc)[x << 1] |
      ((GMB_MapperExRAM(fc)[(x << 1) + 1] & 15) << 8)) + 1)
      << 4;
  int32 amp = (GMB_MapperExRAM(fc)[0x8 + x] & 15) << 6;

  amp += amp >> 1;

  if (!(GMB_MapperExRAM(fc)[0x7] & (1 << x))) {
    for (uint32 V = CAYBC[x]; V < fceulib__.sound->SoundTS(); V++) {
      if (dcount[x]) fceulib__.sound->WaveHi[V] += amp;
      vcount[x]--;
      if (vcount[x] <= 0) {
        dcount[x] ^= 1;
        vcount[x] = freq;
      }
    }
  }
  CAYBC[x] = fceulib__.sound->SoundTS();
}

static void AYSound(FC *fc, int Count) {
  DoAYSQ(0);
  DoAYSQ(1);
  DoAYSQ(2);
  for (int x = 0; x < 3; x++) CAYBC[x] = Count;
}

static void AYSoundHQ(FC *fc) {
  DoAYSQHQ(0);
  DoAYSQHQ(1);
  DoAYSQHQ(2);
}

static void AYHiSync(FC *fc, int32 ts) {
  for (int x = 0; x < 3; x++) {
    CAYBC[x] = ts;
  }
}

static void SunIRQHook(FC *fc, int a) {
  if (fceulib__.ines->iNESIRQa) {
    fceulib__.ines->iNESIRQCount -= a;
    if (fceulib__.ines->iNESIRQCount <= 0) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      fceulib__.ines->iNESIRQa = 0;
      fceulib__.ines->iNESIRQCount = 0xFFFF;
    }
  }
}

void Mapper69_StateRestore(int version) {
  FC *fc = &fceulib__;
  if (GMB_mapbyte1(fc)[1] & 0x40) {
    if (GMB_mapbyte1(fc)[1] & 0x80) {
      // Select WRAM
      fceulib__.cart->setprg8r(0x10, 0x6000, 0);
    }
  } else {
    fceulib__.cart->setprg8(0x6000, GMB_mapbyte1(fc)[1]);
  }
}

void Mapper69_ESI(FC *fc) {
  fceulib__.sound->GameExpSound.RChange = Mapper69_ESI;
  fceulib__.sound->GameExpSound.HiSync = AYHiSync;
  memset(dcount, 0, sizeof(dcount));
  memset(vcount, 0, sizeof(vcount));
  memset(CAYBC, 0, sizeof(CAYBC));
}

void NSFAY_Init() {
  sunindex = 0;
  fceulib__.fceu->SetWriteHandler(0xc000, 0xdfff, Mapper69_SWL);
  fceulib__.fceu->SetWriteHandler(0xe000, 0xffff, Mapper69_SWH);
  Mapper69_ESI(&fceulib__);
}

void Mapper69_init() {
  FC *fc = &fceulib__;
  sunindex = 0;

  fceulib__.cart->SetupCartPRGMapping(0x10, GMB_WRAM(fc), 8192, 1);

  fceulib__.fceu->SetWriteHandler(0x8000, 0xbfff, Mapper69_write);
  fceulib__.fceu->SetWriteHandler(0xc000, 0xdfff, Mapper69_SWL);
  fceulib__.fceu->SetWriteHandler(0xe000, 0xffff, Mapper69_SWH);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7fff, SUN5BWRAM);
  fceulib__.fceu->SetReadHandler(0x6000, 0x7fff, SUN5AWRAM);
  Mapper69_ESI(&fceulib__);
  fceulib__.X->MapIRQHook = SunIRQHook;
  fceulib__.ines->MapStateRestore = Mapper69_StateRestore;
}
