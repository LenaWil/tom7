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

namespace {
struct Mapper69 : public MapInterface {
  using MapInterface::MapInterface;

  uint8 sunindex = 0;

  int32 vcount[3] = {};
  int32 dcount[3] = {};
  int CAYBC[3] = {};
  
  #define sunselect GMB_mapbyte1(fc)[0]
  #define sungah GMB_mapbyte1(fc)[1]

  void SUN5BWRAM(DECLFW_ARGS) {
    if ((sungah & 0xC0) == 0xC0) (GMB_WRAM(fc) - 0x6000)[A] = V;
  }

  DECLFR_RET SUN5AWRAM(DECLFR_ARGS) {
    if ((sungah & 0xC0) == 0x40) return fc->X->DB;
    return Cart::CartBROB(DECLFR_FORWARD);
  }

  void Mapper69_SWL(DECLFW_ARGS) {
    sunindex = V % 14;
  }

  void Mapper69_SWH(DECLFW_ARGS) {
    fc->sound->GameExpSound.Fill = [](FC *fc, int count) {
      ((Mapper69 *)fc->fceu->mapiface)->AYSound(count);
    };
    fc->sound->GameExpSound.HiFill = [](FC *fc) {
      ((Mapper69 *)fc->fceu->mapiface)->AYSoundHQ();
    };
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

  void Mapper69_write(DECLFW_ARGS) {
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
	      fc->cart->setprg8r(0x10, 0x6000, 0);
	    }
	  } else {
	    fc->cart->setprg8(0x6000, V);
	  }
	  break;
	case 9: ROM_BANK8(fc, 0x8000, V); break;
	case 0xa: ROM_BANK8(fc, 0xa000, V); break;
	case 0xb: ROM_BANK8(fc, 0xc000, V); break;
	case 0xc:
	  switch (V & 3) {
	  case 0: fc->ines->MIRROR_SET2(1); break;
	  case 1: fc->ines->MIRROR_SET2(0); break;
	  case 2: fc->ines->onemir(0); break;
	  case 3: fc->ines->onemir(1); break;
	  }
	  break;
	case 0xd:
	  fc->ines->iNESIRQa = V;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0xe:
	  fc->ines->iNESIRQCount &= 0xFF00;
	  fc->ines->iNESIRQCount |= V;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0xf:
	  fc->ines->iNESIRQCount &= 0x00FF;
	  fc->ines->iNESIRQCount |= V << 8;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	}
      break;
    }
  }

  void DoAYSQ(int x) {
    int32 freq =
      ((GMB_MapperExRAM(fc)[x << 1] |
	((GMB_MapperExRAM(fc)[(x << 1) + 1] & 15) << 8)) + 1)
      << (4 + 17);
    int32 amp = (GMB_MapperExRAM(fc)[0x8 + x] & 15) << 2;
    int32 start, end;

    amp += amp >> 1;

    start = CAYBC[x];
    end = (fc->sound->SoundTS() << 16) / fc->sound->soundtsinc;
    if (end <= start) return;
    CAYBC[x] = end;

    if (amp) {
      for (int V = start; V < end; V++) {
	if (dcount[x]) fc->sound->Wave[V >> 4] += amp;
	vcount[x] -= fc->sound->nesincsize;
	while (vcount[x] <= 0) {
	  dcount[x] ^= 1;
	  vcount[x] += freq;
	}
      }
    }
  }

  void DoAYSQHQ(int x) {
    FC *fc = &fceulib__;
    int32 freq =
      ((GMB_MapperExRAM(fc)[x << 1] |
	((GMB_MapperExRAM(fc)[(x << 1) + 1] & 15) << 8)) + 1)
	<< 4;
    int32 amp = (GMB_MapperExRAM(fc)[0x8 + x] & 15) << 6;

    amp += amp >> 1;

    if (!(GMB_MapperExRAM(fc)[0x7] & (1 << x))) {
      for (uint32 V = CAYBC[x]; V < fc->sound->SoundTS(); V++) {
	if (dcount[x]) fc->sound->WaveHi[V] += amp;
	vcount[x]--;
	if (vcount[x] <= 0) {
	  dcount[x] ^= 1;
	  vcount[x] = freq;
	}
      }
    }
    CAYBC[x] = fc->sound->SoundTS();
  }

  void AYSound(int Count) {
    DoAYSQ(0);
    DoAYSQ(1);
    DoAYSQ(2);
    for (int x = 0; x < 3; x++) CAYBC[x] = Count;
  }

  void AYSoundHQ() {
    DoAYSQHQ(0);
    DoAYSQHQ(1);
    DoAYSQHQ(2);
  }

  void AYHiSync(int32 ts) {
    for (int x = 0; x < 3; x++) {
      CAYBC[x] = ts;
    }
  }

  void SunIRQHook(int a) {
    if (fc->ines->iNESIRQa) {
      fc->ines->iNESIRQCount -= a;
      if (fc->ines->iNESIRQCount <= 0) {
	fc->X->IRQBegin(FCEU_IQEXT);
	fc->ines->iNESIRQa = 0;
	fc->ines->iNESIRQCount = 0xFFFF;
      }
    }
  }

  void StateRestore(int version) override {
    FC *fc = &fceulib__;
    if (GMB_mapbyte1(fc)[1] & 0x40) {
      if (GMB_mapbyte1(fc)[1] & 0x80) {
	// Select WRAM
	fc->cart->setprg8r(0x10, 0x6000, 0);
      }
    } else {
      fc->cart->setprg8(0x6000, GMB_mapbyte1(fc)[1]);
    }
  }

  void Mapper69_ESI() {
    fc->sound->GameExpSound.RChange = [](FC *fc) {
      ((Mapper69 *)fc->fceu->mapiface)->Mapper69_ESI();
    };
    fc->sound->GameExpSound.HiSync = [](FC *fc, int32 ts) {
      ((Mapper69 *)fc->fceu->mapiface)->AYHiSync(ts);
    };
    memset(dcount, 0, sizeof(dcount));
    memset(vcount, 0, sizeof(vcount));
    memset(CAYBC, 0, sizeof(CAYBC));
  }

};
}

MapInterface *Mapper69_init(FC *fc) {
  Mapper69 *m = new Mapper69(fc);
  fc->cart->SetupCartPRGMapping(0x10, GMB_WRAM(fc), 8192, 1);

  fc->fceu->SetWriteHandler(0x8000, 0xbfff, [](DECLFW_ARGS) {
    ((Mapper69*)fc->fceu->mapiface)->Mapper69_write(DECLFW_FORWARD);
  });
  fc->fceu->SetWriteHandler(0xc000, 0xdfff, [](DECLFW_ARGS) {
    ((Mapper69*)fc->fceu->mapiface)->Mapper69_SWL(DECLFW_FORWARD);
  });
  fc->fceu->SetWriteHandler(0xe000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper69*)fc->fceu->mapiface)->Mapper69_SWH(DECLFW_FORWARD);
  });
  fc->fceu->SetWriteHandler(0x6000, 0x7fff, [](DECLFW_ARGS) {
    ((Mapper69*)fc->fceu->mapiface)->SUN5BWRAM(DECLFW_FORWARD);
  });
  fc->fceu->SetReadHandler(0x6000, 0x7fff, [](DECLFR_ARGS) {
    return ((Mapper69 *)fc->fceu->mapiface)->SUN5AWRAM(DECLFR_FORWARD);
  });
  m->Mapper69_ESI();
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper69 *)fc->fceu->mapiface)->SunIRQHook(a);
  };

  return m;
}

#if 0
// deleted nsf -tom7
void NSFAY_Init() {
  sunindex = 0;
  fc->fceu->SetWriteHandler(0xc000, 0xdfff, Mapper69_SWL);
  fc->fceu->SetWriteHandler(0xe000, 0xffff, Mapper69_SWH);
  Mapper69_ESI(&fceulib__);
}
#endif
