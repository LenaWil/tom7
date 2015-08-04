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

static uint8 cmd, mir, rmode, IRQmode;
static uint8 DRegs[11];
static uint8 IRQCount, IRQa, IRQLatch;
static int smallcount;

static vector<SFORMAT> Rambo_StateRegs = {
    {&cmd, 1, "CMD0"},         {&mir, 1, "MIR0"},
    {&rmode, 1, "RMOD"},      {&IRQmode, 1, "IRQM"},
    {&IRQCount, 1, "IRQC"},   {&IRQa, 1, "IRQA"},
    {&IRQLatch, 1, "IRQL"},   {DRegs, 11, "DREG"},
    {&smallcount, 4, "SMAC"}};

static void (*setchr1wrap)(unsigned int A, unsigned int V);
// static int nomirror;

static void RAMBO1_IRQHook(FC *fc, int a) {
  if (!IRQmode) return;

  TRACEF("RAMBO1: %d %d %02x %02x", a, smallcount, IRQCount, IRQa);

  smallcount += a;
  while (smallcount >= 4) {
    smallcount -= 4;
    IRQCount--;
    if (IRQCount == 0xFF)
      if (IRQa) fceulib__.X->IRQBegin(FCEU_IQEXT);
  }
}

static void RAMBO1_hb() {
  if (IRQmode) return;
  if (fceulib__.ppu->scanline == 240)
    return; /* hmm.  Maybe that should be an mmc3-only call in fce.c. */
  rmode = 0;
  IRQCount--;
  if (IRQCount == 0xFF) {
    if (IRQa) {
      rmode = 1;
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
  }
}

static void Synco() {

  if (cmd & 0x20) {
    setchr1wrap(0x0000, DRegs[0]);
    setchr1wrap(0x0800, DRegs[1]);
    setchr1wrap(0x0400, DRegs[8]);
    setchr1wrap(0x0c00, DRegs[9]);
  } else {
    setchr1wrap(0x0000, (DRegs[0] & 0xFE));
    setchr1wrap(0x0400, (DRegs[0] & 0xFE) | 1);
    setchr1wrap(0x0800, (DRegs[1] & 0xFE));
    setchr1wrap(0x0C00, (DRegs[1] & 0xFE) | 1);
  }

  for (int x = 0; x < 4; x++) setchr1wrap(0x1000 + x * 0x400, DRegs[2 + x]);

  fceulib__.cart->setprg8(0x8000, DRegs[6]);
  fceulib__.cart->setprg8(0xA000, DRegs[7]);

  fceulib__.cart->setprg8(0xC000, DRegs[10]);
}

static DECLFW(RAMBO1_write) {
  switch (A & 0xF001) {
    case 0xa000:
      mir = V & 1;
      //                 if (!nomirror)
      fceulib__.cart->setmirror(mir ^ 1);
      break;
    case 0x8000: cmd = V; break;
    case 0x8001:
      if ((cmd & 0xF) < 10)
        DRegs[cmd & 0xF] = V;
      else if ((cmd & 0xF) == 0xF)
        DRegs[10] = V;
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
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      if (rmode == 1) IRQCount = IRQLatch;
      break;
    case 0xE001:
      IRQa = 1;
      if (rmode == 1) IRQCount = IRQLatch;
      break;
  }
}

static void RAMBO1_Restore(FC *fc, int version) {
  Synco();
  //  if (!nomirror)
  fceulib__.cart->setmirror(mir ^ 1);
}

static void RAMBO1_init() {
  for (int x = 0; x < 11; x++) DRegs[x] = ~0;
  cmd = mir = 0;
  //  if (!nomirror)
  fceulib__.cart->setmirror(1);
  Synco();
  fceulib__.ppu->GameHBIRQHook = RAMBO1_hb;
  fceulib__.X->MapIRQHook = RAMBO1_IRQHook;
  fceulib__.fceu->GameStateRestore = RAMBO1_Restore;
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, RAMBO1_write);
  fceulib__.state->AddExVec(Rambo_StateRegs);
}

static void CHRWrap(unsigned int A, unsigned int V) {
  fceulib__.cart->setchr1(A, V);
}

void Mapper64_init() {
  setchr1wrap = CHRWrap;
  //  nomirror=0;
  RAMBO1_init();
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
