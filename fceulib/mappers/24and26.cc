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
struct Mapper24and26 : public MapInterface {
  const bool swaparoo;

  void (Mapper24and26::*sfun[3])() = {nullptr, nullptr, nullptr};

  #define vrctemp(fc) GMB_mapbyte1(fc)[0]
  #define VPSG2(fc) GMB_mapbyte3(fc)
  #define VPSG(fc) GMB_mapbyte2(fc)

  int acount = 0;

  int32 CVBC[3] = {};
  int32 vcount[3] = {};
  int32 dcount[2] = {};
  
  void KonamiIRQHook(int a) {
    static constexpr int LCYCS = 341;
    //  #define LCYCS ((227*2)+1)
    if (fc->ines->iNESIRQa) {
      acount += a * 3;
      while (acount >= LCYCS) {
	acount -= LCYCS;
	fc->ines->iNESIRQCount++;
	if (fc->ines->iNESIRQCount == 0x100) {
	  fc->X->IRQBegin(FCEU_IQEXT);
	  fc->ines->iNESIRQCount = fc->ines->iNESIRQLatch;
	}
      }
    }
  }

  void VRC6SW(DECLFW_ARGS) {
    A &= 0xF003;
    if (A >= 0x9000 && A <= 0x9002) {
      VPSG(fc)[A & 3] = V;
      if (sfun[0]) (this->*sfun[0])();
    } else if (A >= 0xa000 && A <= 0xa002) {
      VPSG(fc)[4 | (A & 3)] = V;
      if (sfun[1]) (this->*sfun[1])();
    } else if (A >= 0xb000 && A <= 0xb002) {
      VPSG2(fc)[A & 3] = V;
      if (sfun[2]) (this->*sfun[2])();
    }
  }

  void Mapper24_write(DECLFW_ARGS) {
    if (swaparoo) A = (A & 0xFFFC) | ((A >> 1) & 1) | ((A << 1) & 2);
    if (A >= 0x9000 && A <= 0xb002) {
      VRC6SW(DECLFW_FORWARD);
      return;
    }
    A &= 0xF003;
    //        if (A>=0xF000) printf("%d, %d,
    //        $%04x:$%02x\n",scanline,timestamp,A,V);
    switch (A & 0xF003) {
    case 0x8000: ROM_BANK16(fc, 0x8000, V); break;
    case 0xB003:
      switch (V & 0xF) {
      case 0x0: fc->ines->MIRROR_SET2(1); break;
      case 0x4: fc->ines->MIRROR_SET2(0); break;
      case 0x8: fc->ines->onemir(0); break;
      case 0xC: fc->ines->onemir(1); break;
      }
      break;
    case 0xC000: ROM_BANK8(fc, 0xC000, V); break;
    case 0xD000: VROM_BANK1(fc, 0x0000, V); break;
    case 0xD001: VROM_BANK1(fc, 0x0400, V); break;
    case 0xD002: VROM_BANK1(fc, 0x0800, V); break;
    case 0xD003: VROM_BANK1(fc, 0x0c00, V); break;
    case 0xE000: VROM_BANK1(fc, 0x1000, V); break;
    case 0xE001: VROM_BANK1(fc, 0x1400, V); break;
    case 0xE002: VROM_BANK1(fc, 0x1800, V); break;
    case 0xE003: VROM_BANK1(fc, 0x1c00, V); break;
    case 0xF000:
      fc->ines->iNESIRQLatch = V;
      // acount=0;
      break;
    case 0xF001:
      fc->ines->iNESIRQa = V & 2;
      vrctemp(fc) = V & 1;
      if (V & 2) {
	fc->ines->iNESIRQCount = fc->ines->iNESIRQLatch;
	acount = 0;
      }
      fc->X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xf002:
      fc->ines->iNESIRQa = vrctemp(fc);
      fc->X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xF003: break;
    }
  }

  inline void DoSQV(int x) {
    int32 V;
    int32 amp = (((VPSG(fc)[x << 2] & 15) << 8) * 6 / 8) >> 4;
    int32 start, end;

    start = CVBC[x];
    end = (fc->sound->SoundTS() << 16) / fc->sound->soundtsinc;
    if (end <= start) return;
    CVBC[x] = end;

    if (VPSG(fc)[(x << 2) | 0x2] & 0x80) {
      if (VPSG(fc)[x << 2] & 0x80) {
	for (V = start; V < end; V++) fc->sound->Wave[V >> 4] += amp;
      } else {
	int32 thresh = (VPSG(fc)[x << 2] >> 4) & 7;
	int32 freq =
	    ((VPSG(fc)[(x << 2) | 0x1] | ((VPSG(fc)[(x << 2) | 0x2] & 15) << 8)) + 1)
	    << 17;
	for (V = start; V < end; V++) {
	  /* Greater than, not >=.  Important. */
	  if (dcount[x] > thresh) fc->sound->Wave[V >> 4] += amp;
	  vcount[x] -= fc->sound->nesincsize;
	  /* Should only be <0 in a few circumstances. */
	  while (vcount[x] <= 0) {
	    vcount[x] += freq;
	    dcount[x] = (dcount[x] + 1) & 15;
	  }
	}
      }
    }
  }

  void DoSQV1() {
    DoSQV(0);
  }

  void DoSQV2() {
    DoSQV(1);
  }

  int32 sawv_saw1phaseacc = 0;
  uint8 sawv_b3 = 0;
  int32 sawv_phaseacc = 0;
  uint32 sawv_duff = 0;
  void DoSawV() {
    int32 start = CVBC[2];
    int32 end = (fc->sound->SoundTS() << 16) / fc->sound->soundtsinc;
    if (end <= start) return;
    CVBC[2] = end;

    if (VPSG2(fc)[2] & 0x80) {
      uint32 freq3;

      freq3 = (VPSG2(fc)[1] + ((VPSG2(fc)[2] & 15) << 8) + 1);

      for (int V = start; V < end; V++) {
	sawv_saw1phaseacc -= fc->sound->nesincsize;
	if (sawv_saw1phaseacc <= 0) {
	  int32 t;
	  do {
	    t = freq3;
	    t <<= 18;
	    sawv_saw1phaseacc += t;
	    sawv_phaseacc += VPSG2(fc)[0] & 0x3f;
	    sawv_b3++;
	    if (sawv_b3 == 7) {
	      sawv_b3 = 0;
	      sawv_phaseacc = 0;
	    }
	  } while (sawv_saw1phaseacc <= 0);

	  sawv_duff = (((sawv_phaseacc >> 3) & 0x1f) << 4) * 6 / 8;
	}
	fc->sound->Wave[V >> 4] += sawv_duff;
      }
    }
  }

  inline void DoSQVHQ(int x) {
    const int32 amp = ((VPSG(fc)[x << 2] & 15) << 8) * 6 / 8;

    if (VPSG(fc)[(x << 2) | 0x2] & 0x80) {
      if (VPSG(fc)[x << 2] & 0x80) {
	for (uint32 V = CVBC[x]; V < fc->sound->SoundTS(); V++)
	  fc->sound->WaveHi[V] += amp;
      } else {
	const int32 thresh = (VPSG(fc)[x << 2] >> 4) & 7;
	for (uint32 V = CVBC[x]; V < fc->sound->SoundTS(); V++) {
	  if (dcount[x] > thresh) /* Greater than, not >=.  Important. */
	    fc->sound->WaveHi[V] += amp;
	  vcount[x]--;
	  /* Should only be <0 in a few circumstances. */
	  if (vcount[x] <= 0) {
	    vcount[x] = (VPSG(fc)[(x << 2) | 0x1] |
			 ((VPSG(fc)[(x << 2) | 0x2] & 15) << 8)) + 1;
	    dcount[x] = (dcount[x] + 1) & 15;
	  }
	}
      }
    }
    CVBC[x] = fc->sound->SoundTS();
  }

  void DoSQV1HQ() {
    DoSQVHQ(0);
  }

  void DoSQV2HQ() {
    DoSQVHQ(1);
  }

  uint8 sawvhq_b3 = 0;
  int32 sawvhq_phaseacc = 0;
  void DoSawVHQ() {
    if (VPSG2(fc)[2] & 0x80) {
      for (uint32 V = CVBC[2]; V < fc->sound->SoundTS(); V++) {
	fc->sound->WaveHi[V] += (((sawvhq_phaseacc >> 3) & 0x1f) << 8) * 6 / 8;
	vcount[2]--;
	if (vcount[2] <= 0) {
	  vcount[2] = (VPSG2(fc)[1] + ((VPSG2(fc)[2] & 15) << 8) + 1) << 1;
	  sawvhq_phaseacc += VPSG2(fc)[0] & 0x3f;
	  sawvhq_b3++;
	  if (sawvhq_b3 == 7) {
	    sawvhq_b3 = 0;
	    sawvhq_phaseacc = 0;
	  }
	}
      }
    }
    CVBC[2] = fc->sound->SoundTS();
  }

  void VRC6Sound(int Count) {
    DoSQV1();
    DoSQV2();
    DoSawV();
    for (int x = 0; x < 3; x++) CVBC[x] = Count;
  }

  void VRC6SoundHQ() {
    DoSQV1HQ();
    DoSQV2HQ();
    DoSawVHQ();
  }

  void VRC6SyncHQ(int32 ts) {
    for (int x = 0; x < 3; x++) CVBC[x] = ts;
  }

  void VRC6_ESI() {
    fc->sound->GameExpSound.RChange = [](FC *fc) {
      ((Mapper24and26 *)fc->fceu->mapiface)->VRC6_ESI();
    };
    fc->sound->GameExpSound.Fill = [](FC *fc, int Count) {
      ((Mapper24and26 *)fc->fceu->mapiface)->VRC6Sound(Count);
    };
    fc->sound->GameExpSound.HiFill = [](FC *fc) {
      ((Mapper24and26 *)fc->fceu->mapiface)->VRC6SoundHQ();
    };
    fc->sound->GameExpSound.HiSync = [](FC *fc, int32 ts) {
      ((Mapper24and26 *)fc->fceu->mapiface)->VRC6SyncHQ(ts);
    };

    memset(CVBC, 0, sizeof(CVBC));
    memset(vcount, 0, sizeof(vcount));
    memset(dcount, 0, sizeof(dcount));
    if (FCEUS_SNDRATE) {
      if (FCEUS_SOUNDQ >= 1) {
	sfun[0] = &Mapper24and26::DoSQV1HQ;
	sfun[1] = &Mapper24and26::DoSQV2HQ;
	sfun[2] = &Mapper24and26::DoSawVHQ;
      } else {
	sfun[0] = &Mapper24and26::DoSQV1;
	sfun[1] = &Mapper24and26::DoSQV2;
	sfun[2] = &Mapper24and26::DoSawV;
      }
    } else {
      sfun[0] = nullptr;
      sfun[1] = nullptr;
      sfun[2] = nullptr;
    }
  }

  Mapper24and26(FC *fc, bool swaparoo) : MapInterface(fc), swaparoo(swaparoo) {
  }
};
}

MapInterface *Mapper24_init(FC *fc) {
  Mapper24and26 *m = new Mapper24and26(fc, false);
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper24and26*)fc->fceu->mapiface)->Mapper24_write(DECLFW_FORWARD);
  });
  m->VRC6_ESI();
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper24and26 *)fc->fceu->mapiface)->KonamiIRQHook(a);
  };
  return m;
}

MapInterface *Mapper26_init(FC *fc) {
  Mapper24and26 *m = new Mapper24and26(fc, true);
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper24and26*)fc->fceu->mapiface)->Mapper24_write(DECLFW_FORWARD);
  });
  m->VRC6_ESI();
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper24and26 *)fc->fceu->mapiface)->KonamiIRQHook(a);
  };
  return m;
}

#if 0
// NSF disabled. -tom7
MapInterface *NSFVRC6_Init(FC *fc) {
  Mapper24and26 *m = new Mapper24and26(fc, false);
  m->VRC6_ESI();
  fc->fceu->SetWriteHandler(0x8000, 0xbfff, [](DECLFW_ARGS) {
    ((Mapper24and26*)fc->fceu->mapinterface)->VRC6SW(DECLFW_FORWARD);
  });
}
#endif
