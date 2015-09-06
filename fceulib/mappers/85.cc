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
#include "emu2413.h"

#define vrctemp GMB_mapbyte1(fc)[0]

namespace {
struct Mapper85 : public MapInterface {
  using MapInterface::MapInterface;
  
  uint8 indox = 0;
  int acount = 0;

  OPLL *VRC7Sound = nullptr;
  int dwave = 0;

  EMU2413 emu2413;
  
  void DoVRC7Sound() {
    if (FCEUS_SOUNDQ >= 1) return;
    int32 z = ((fc->sound->SoundTS() << 16) / fc->sound->soundtsinc) >> 4;
    int32 a = z - dwave;

    emu2413.OPLL_FillBuffer(VRC7Sound, &fc->sound->Wave[dwave], a, 1);

    dwave += a;
  }

  void UpdateOPLNEO(int32 *Wave, int Count) {
    emu2413.OPLL_FillBuffer(VRC7Sound, Wave, Count, 4);
  }

  void UpdateOPL(int Count) {
    int32 z, a;

    z = ((fc->sound->SoundTS() << 16) / fc->sound->soundtsinc) >> 4;
    a = z - dwave;

    if (VRC7Sound && a)
      emu2413.OPLL_FillBuffer(VRC7Sound, &fc->sound->Wave[dwave], a, 1);

    dwave = 0;
  }

  void DaMirror(int V) {
    int salpo[4] = {MI_V, MI_H, MI_0, MI_1};
    fc->cart->setmirror(salpo[V & 3]);
  }

  void Mapper85_write(DECLFW_ARGS) {
    A |= (A & 8) << 1;

    if (A >= 0xa000 && A <= 0xDFFF) {
      // printf("$%04x, $%04x\n",fc->X->PC,A);
      A &= 0xF010;
      {
	int x = ((A >> 4) & 1) | ((A - 0xA000) >> 11);
	GMB_mapbyte3(fc)[x] = V;
	fc->cart->setchr1(x << 10, V);
      }
    } else if (A == 0x9030) {
      if (FCEUS_SNDRATE) {
	emu2413.OPLL_writeReg(VRC7Sound, indox, V);
	fc->sound->GameExpSound.Fill = [](FC *fc, int c) {
	  ((Mapper85 *)fc->fceu->mapiface)->UpdateOPL(c);
	};
	fc->sound->GameExpSound.NeoFill = [](FC *fc, int32 *Wave, int Count) {
	  ((Mapper85 *)fc->fceu->mapiface)->UpdateOPLNEO(Wave, Count);
	};
      }
    } else {
      switch (A & 0xF010) {
	case 0x8000:
	  GMB_mapbyte2(fc)[0] = V;
	  fc->cart->setprg8(0x8000, V);
	  break;
	case 0x8010:
	  GMB_mapbyte2(fc)[1] = V;
	  fc->cart->setprg8(0xa000, V);
	  break;
	case 0x9000:
	  GMB_mapbyte2(fc)[2] = V;
	  fc->cart->setprg8(0xc000, V);
	  break;
	case 0x9010: indox = V; break;
	case 0xe000:
	  GMB_mapbyte2(fc)[3] = V;
	  DaMirror(V);
	  break;
	case 0xE010:
	  fc->ines->iNESIRQLatch = V;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0xF000:
	  fc->ines->iNESIRQa = V & 2;
	  vrctemp = V & 1;
	  if (V & 2) {
	    fc->ines->iNESIRQCount = fc->ines->iNESIRQLatch;
	  }
	  acount = 0;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
	case 0xf010:
	  if (vrctemp)
	    fc->ines->iNESIRQa = 1;
	  else
	    fc->ines->iNESIRQa = 0;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  break;
      }
    }
  }

  void KonamiIRQHook(int a) {
    #define ACBOO 341
    //  #define ACBOO ((227*2)+1)
    if (fc->ines->iNESIRQa) {
      acount += a * 3;

      if (acount >= ACBOO) {
      doagainbub:
	acount -= ACBOO;
	fc->ines->iNESIRQCount++;
	if (fc->ines->iNESIRQCount & 0x100) {
	  fc->X->IRQBegin(FCEU_IQEXT);
	  fc->ines->iNESIRQCount = fc->ines->iNESIRQLatch;
	}
	if (acount >= ACBOO) goto doagainbub;
      }
    }
  }

  void StateRestore(int version) override {
    if (version < 7200) {
      for (int x = 0; x < 8; x++) {
	GMB_mapbyte3(fc)[x] =
	  fc->ines->iNESCHRBankList[x];
      }
      for (int x = 0; x < 3; x++)
	GMB_mapbyte2(fc)[x] = GMB_PRGBankList(fc)[x];

      GMB_mapbyte2(fc)[3] = (fc->ines->iNESMirroring < 0x10) ?
			fc->ines->iNESMirroring :
			fc->ines->iNESMirroring - 0xE;
    }

    for (int x = 0; x < 8; x++)
      fc->cart->setchr1(x * 0x400, GMB_mapbyte3(fc)[x]);
    for (int x = 0; x < 3; x++)
      fc->cart->setprg8(0x8000 + x * 8192, GMB_mapbyte2(fc)[x]);
    DaMirror(GMB_mapbyte2(fc)[3]);
    // LoadOPL();
  }

  void M85SC() {
    if (VRC7Sound) emu2413.OPLL_set_rate(VRC7Sound, FCEUS_SNDRATE);
  }

  void M85SKill() {
    if (VRC7Sound) emu2413.OPLL_delete(VRC7Sound);
    VRC7Sound = nullptr;
  }

  void VRC7SI() {
    fc->sound->GameExpSound.RChange = [](FC *fc) {
      ((Mapper85 *)fc->fceu->mapiface)->M85SC();
    };
    fc->sound->GameExpSound.Kill = [](FC *fc) {
      ((Mapper85 *)fc->fceu->mapiface)->M85SKill();
    };

    VRC7Sound =
      emu2413.OPLL_new(3579545, FCEUS_SNDRATE ? FCEUS_SNDRATE : 44100);
    // Why twice? _new even calls reset, last thing. -tom7
    emu2413.OPLL_reset(VRC7Sound);
    emu2413.OPLL_reset(VRC7Sound);
  }
};
}

  
MapInterface *Mapper85_init(FC *fc) {
  Mapper85 *m = new Mapper85(fc);
  fc->X->MapIRQHook = [](FC *fc, int a) {
    ((Mapper85 *)fc->fceu->mapiface)->KonamiIRQHook(a);
  };
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper85*)fc->fceu->mapiface)->Mapper85_write(DECLFW_FORWARD);
  });

  if (!fc->ines->VROM_size)
    fc->cart->SetupCartCHRMapping(0, GMB_CHRRAM(fc), 8192, 1);
  // AddExState(VRC7Instrument, 16, 0, "VC7I");
  // AddExState(VRC7Chan, sizeof(VRC7Chan), 0, "V7CH");
  m->VRC7SI();
  return m;
}

#if 0
  // killed nsf -tom7
void NSFVRC7_Init() {
  fc->fceu->SetWriteHandler(0x9010, 0x901F, Mapper85_write);
  fc->fceu->SetWriteHandler(0x9030, 0x903F, Mapper85_write);
  VRC7SI();
}

#endif
