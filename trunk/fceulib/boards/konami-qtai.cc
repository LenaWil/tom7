/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005-2008 CaH4e3
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
 *
 * CAI Shogakko no Sansu
 */

#include "mapinc.h"

static uint8 QTAINTRAM[2048];
static writefunc old2007wrap;

static uint16 CHRSIZE = 8192;
static uint16 WRAMSIZE = 8192 + 4096;
static uint8 *CHRRAM = nullptr;
static uint8 *WRAM = nullptr;

static uint8 IRQa, K4IRQ;
static uint32 IRQLatch, IRQCount;

static uint8 regs[16];

static SFORMAT StateRegs[] = {{&IRQCount, 1, "IRQC"}, {&IRQLatch, 1, "IRQL"},
                              {&IRQa, 1, "IRQA"},     {&K4IRQ, 1, "KIRQ"},
                              {regs, 16, "REGS"},     {0}};

static void chrSync() {
  fceulib__.cart->setchr4r(0x10, 0x0000, regs[5] & 1);
  fceulib__.cart->setchr4r(0x10, 0x1000, 0);
}

static void Sync() {
  chrSync();
  //  if(regs[0xA]&0x10)
  //  {
  /*    setchr1r(0x10,0x0000,(((regs[5]&1))<<2)+0);
      setchr1r(0x10,0x0400,(((regs[5]&1))<<2)+1);
      setchr1r(0x10,0x0800,(((regs[5]&1))<<2)+2);
      setchr1r(0x10,0x0c00,(((regs[5]&1))<<2)+3);
      setchr1r(0x10,0x1000,0);
      setchr1r(0x10,0x1400,1);
      setchr1r(0x10,0x1800,2);
      setchr1r(0x10,0x1c00,3);*/
  /*    setchr1r(0x10,0x0000,(((regs[5]&1))<<2)+0);
      setchr1r(0x10,0x0400,(((regs[5]&1))<<2)+1);
      setchr1r(0x10,0x0800,(((regs[5]&1))<<2)+2);
      setchr1r(0x10,0x0c00,(((regs[5]&1))<<2)+3);
      setchr1r(0x10,0x1000,(((regs[5]&1)^1)<<2)+4);
      setchr1r(0x10,0x1400,(((regs[5]&1)^1)<<2)+5);
      setchr1r(0x10,0x1800,(((regs[5]&1)^1)<<2)+6);
      setchr1r(0x10,0x1c00,(((regs[5]&1)^1)<<2)+7);
  */
  //  }
  //  else
  //  {
  /*
      setchr1r(0x10,0x0000,(((regs[5]&1)^1)<<2)+0);
      setchr1r(0x10,0x0400,(((regs[5]&1)^1)<<2)+1);
      setchr1r(0x10,0x0800,(((regs[5]&1)^1)<<2)+2);
      setchr1r(0x10,0x0c00,(((regs[5]&1)^1)<<2)+3);
      setchr1r(0x10,0x1000,(((regs[5]&1))<<2)+4);
      setchr1r(0x10,0x1400,(((regs[5]&1))<<2)+5);
      setchr1r(0x10,0x1800,(((regs[5]&1))<<2)+6);
      setchr1r(0x10,0x1c00,(((regs[5]&1))<<2)+7);
  //  }
  //*/
  fceulib__.cart->setprg4r(0x10, 0x6000, regs[0] & 1);
  if (regs[2] >= 0x40)
    fceulib__.cart->setprg8r(1, 0x8000, (regs[2] - 0x40));
  else
    fceulib__.cart->setprg8r(0, 0x8000, (regs[2] & 0x3F));
  if (regs[3] >= 0x40)
    fceulib__.cart->setprg8r(1, 0xA000, (regs[3] - 0x40));
  else
    fceulib__.cart->setprg8r(0, 0xA000, (regs[3] & 0x3F));
  if (regs[4] >= 0x40)
    fceulib__.cart->setprg8r(1, 0xC000, (regs[4] - 0x40));
  else
    fceulib__.cart->setprg8r(0, 0xC000, (regs[4] & 0x3F));

  fceulib__.cart->setprg8r(1, 0xE000, ~0);
  fceulib__.cart->setmirror(MI_V);
}

static DECLFW(M190Write) {
  // FCEU_printf("write %04x:%04x %d, %d\n",A,V,scanline,timestamp);
  regs[(A & 0x0F00) >> 8] = V;
  switch (A) {
    case 0xd600:
      IRQLatch &= 0xFF00;
      IRQLatch |= V;
      break;
    case 0xd700:
      IRQLatch &= 0x00FF;
      IRQLatch |= V << 8;
      break;
    case 0xd900:
      IRQCount = IRQLatch;
      IRQa = V & 2;
      K4IRQ = V & 1;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xd800:
      IRQa = K4IRQ;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
  }
  Sync();
}

static DECLFR(M190Read) {
  // FCEU_printf("read %04x:%04x %d,
  // %d\n",A,regs[(A&0x0F00)>>8],scanline,timestamp);
  return regs[(A & 0x0F00) >> 8] + regs[0x0B];
}
static void VRC5IRQ(FC *fc, int a) {
  if (IRQa) {
    IRQCount += a;
    if (IRQCount & 0x10000) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      //      IRQCount=IRQLatch;
    }
  }
}

static DECLFW(M1902007Wrap) {
  if (A >= 0x2000) {
    if (regs[0xA] & 1)
      QTAINTRAM[A & 0x1FFF] = V;
    else
      old2007wrap(DECLFW_FORWARD);
  }
}

static void M190Power(FC *fc) {
  fceulib__.cart->setprg4r(0x10, 0x7000, 2);

  old2007wrap = fceulib__.fceu->GetWriteHandler(0x2007);
  fceulib__.fceu->SetWriteHandler(0x2007, 0x2007, M1902007Wrap);

  fceulib__.fceu->SetReadHandler(0x6000, 0xFFFF, fceulib__.cart->CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, fceulib__.cart->CartBW);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M190Write);
  fceulib__.fceu->SetReadHandler(0xDC00, 0xDC00, M190Read);
  fceulib__.fceu->SetReadHandler(0xDD00, 0xDD00, M190Read);
  Sync();
}

static void M190Close(FC *fc) {
  free(CHRRAM);
  CHRRAM = nullptr;
  free(WRAM);
  WRAM = nullptr;
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper190_Init(CartInfo *info) {
  info->Power = M190Power;
  info->Close = M190Close;
  fceulib__.fceu->GameStateRestore = StateRestore;

  fceulib__.X->MapIRQHook = VRC5IRQ;
  // PPU_hook=Mapper190_PPU;

  CHRRAM = (uint8 *)FCEU_gmalloc(CHRSIZE);
  fceulib__.cart->SetupCartCHRMapping(0x10, CHRRAM, CHRSIZE, 1);
  fceulib__.state->AddExState(CHRRAM, CHRSIZE, 0, "CRAM");

  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = WRAMSIZE - 4096;
  }

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
