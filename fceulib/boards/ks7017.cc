/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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
 * FDS Conversion
 *
 */

#include "mapinc.h"

#include "tracing.h"

static uint8 reg, mirr;
static int32 IRQa, IRQCount, IRQLatch;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] = {{&mirr, 1, "MIRR"},     {&reg, 1, "REGS"},
                              {&IRQa, 4, "IRQA"},     {&IRQCount, 4, "IRQC"},
                              {&IRQLatch, 4, "IRQL"}, {0}};

static void Sync() {
  fceulib__.cart->setprg16(0x8000, reg);
  fceulib__.cart->setprg16(0xC000, 2);
  fceulib__.cart->setmirror(mirr);
}

static DECLFW(UNLKS7017Write) {
  //  FCEU_printf("bs %04x %02x\n",A,V);
  if ((A & 0xFF00) == 0x4A00) {
    reg = ((A >> 2) & 3) | ((A >> 4) & 4);
  } else if ((A & 0xFF00) == 0x5100) {
    Sync();
  } else if (A == 0x4020) {
    fceulib__.X->IRQEnd(FCEU_IQEXT);
    IRQCount &= 0xFF00;
    IRQCount |= V;
  } else if (A == 0x4021) {
    fceulib__.X->IRQEnd(FCEU_IQEXT);
    IRQCount &= 0xFF;
    IRQCount |= V << 8;
    IRQa = 1;
  } else if (A == 0x4025) {
    mirr = ((V & 8) >> 3) ^ 1;
  }
}

static DECLFR(FDSRead4030) {
  fceulib__.X->IRQEnd(FCEU_IQEXT);
  TRACEF("ks7017 irqlow %02x", fceulib__.X->IRQlow);
  return fceulib__.X->IRQlow & FCEU_IQEXT ? 1 : 0;
}

static void UNL7017IRQ(FC *fc, int a) {
  if (IRQa) {
    IRQCount -= a;
    if (IRQCount <= 0) {
      IRQa = 0;
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
  }
}

static void UNLKS7017Power(FC *fc) {
  Sync();
  fceulib__.cart->setchr8(0);
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetReadHandler(0x4030, 0x4030, FDSRead4030);
  fceulib__.fceu->SetWriteHandler(0x4020, 0x5FFF, UNLKS7017Write);
}

static void UNLKS7017Close(FC *fc) {
  free(WRAM);
  WRAM = nullptr;
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void UNLKS7017_Init(CartInfo *info) {
  info->Power = UNLKS7017Power;
  info->Close = UNLKS7017Close;
  fceulib__.X->MapIRQHook = UNL7017IRQ;

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
