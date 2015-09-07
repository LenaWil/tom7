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
#include <vector>

using namespace std;

namespace {
struct Tengen : public MapInterface {

  uint8 cmd = 0, mir = 0, rmode = 0, IRQmode = 0;
  uint8 DRegs[11] = {};
  uint8 IRQCount = 0, IRQa = 0, IRQLatch = 0;
  int smallcount = 0;

  // static void (*setchr1wrap)(unsigned int A, unsigned int V);
  // static int nomirror;

  void RAMBO1_IRQHook(int a) {
    if (!IRQmode) return;

    TRACEF("RAMBO1: %d %d %02x %02x", a, smallcount, IRQCount, IRQa);

    smallcount += a;
    while (smallcount >= 4) {
      smallcount -= 4;
      IRQCount--;
      if (IRQCount == 0xFF)
	if (IRQa) fc->X->IRQBegin(FCEU_IQEXT);
    }
  }

  void RAMBO1_hb() {
    if (IRQmode) return;
    if (fc->ppu->scanline == 240)
      return; /* hmm.  Maybe that should be an mmc3-only call in fce.c. */
    rmode = 0;
    IRQCount--;
    if (IRQCount == 0xFF) {
      if (IRQa) {
	rmode = 1;
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  void Synco() {
    if (cmd & 0x20) {
      CHRWrap(0x0000, DRegs[0]);
      CHRWrap(0x0800, DRegs[1]);
      CHRWrap(0x0400, DRegs[8]);
      CHRWrap(0x0c00, DRegs[9]);
    } else {
      CHRWrap(0x0000, (DRegs[0] & 0xFE));
      CHRWrap(0x0400, (DRegs[0] & 0xFE) | 1);
      CHRWrap(0x0800, (DRegs[1] & 0xFE));
      CHRWrap(0x0C00, (DRegs[1] & 0xFE) | 1);
    }

    for (int x = 0; x < 4; x++)
      CHRWrap(0x1000 + x * 0x400, DRegs[2 + x]);

    fc->cart->setprg8(0x8000, DRegs[6]);
    fc->cart->setprg8(0xA000, DRegs[7]);

    fc->cart->setprg8(0xC000, DRegs[10]);
  }

  void RAMBO1_write(DECLFW_ARGS) {
    switch (A & 0xF001) {
      case 0xa000:
	mir = V & 1;
	//                 if (!nomirror)
	fc->cart->setmirror(mir ^ 1);
	break;
      case 0x8000: cmd = V; break;
      case 0x8001:
	if ((cmd & 0xF) < 10) {
	  DRegs[cmd & 0xF] = V;
	} else if ((cmd & 0xF) == 0xF) {
	  DRegs[10] = V;
	}
	Synco();
	break;
      case 0xc000:
	IRQLatch = V;
	if (rmode == 1) IRQCount = IRQLatch;
	break;
      case 0xc001:
	rmode = 1;
	IRQCount = IRQLatch;
	IRQmode = V & 1;
	break;
      case 0xE000:
	IRQa = 0;
	fc->X->IRQEnd(FCEU_IQEXT);
	if (rmode == 1) IRQCount = IRQLatch;
	break;
      case 0xE001:
	IRQa = 1;
	if (rmode == 1) IRQCount = IRQLatch;
	break;
    }
  }

  void StateRestore(int version) override {
    Synco();
    //  if (!nomirror)
    fc->cart->setmirror(mir ^ 1);
  }

  explicit Tengen(FC *fc) : MapInterface(fc) {
    for (int x = 0; x < 11; x++) DRegs[x] = ~0;
    //  if (!nomirror)
    fc->cart->setmirror(1);
    Synco();
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((Tengen *)fc->fceu->mapiface)->RAMBO1_hb();
    };
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Tengen *)fc->fceu->mapiface)->RAMBO1_IRQHook(a);
    };
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
      ((Tengen*)fc->fceu->mapiface)->RAMBO1_write(DECLFW_FORWARD);
    });
    fc->state->AddExVec({
      {&cmd, 1, "CMD0"}, {&mir, 1, "MIR0"},
      {&rmode, 1, "RMOD"}, {&IRQmode, 1, "IRQM"},
      {&IRQCount, 1, "IRQC"}, {&IRQa, 1, "IRQA"},
      {&IRQLatch, 1, "IRQL"}, {DRegs, 11, "DREG"},
      {&smallcount, 4, "SMAC"}});
  }

  // was fn pointer setchr1wrap, always set to this function -tom7
  void CHRWrap(unsigned int A, unsigned int V) {
    fc->cart->setchr1(A, V);
  }
};
}
  
MapInterface *Mapper64_init(FC *fc) {
  // setchr1wrap = CHRWrap;
  //  nomirror=0;
  return new Tengen(fc);
}

/*
static int MirCache[8];
static unsigned int PPUCHRBus;

static void MirWrap(unsigned int A, unsigned int V)
{
  MirCache[A>>10]=(V>>7)&1;
  if (PPUCHRBus==(A>>10))
    setmirror(MI_0+((V>>7)&1));
  setchr1(A,V);
}

static void MirrorFear(uint32 A)
{
  A&=0x1FFF;
  A>>=10;
  PPUCHRBus=A;
  setmirror(MI_0+MirCache[A]);
}

void Mapper158_init()
{
  setchr1wrap=MirWrap;
  PPU_hook=MirrorFear;
  nomirror=1;
  RAMBO1_init();
}
*/
