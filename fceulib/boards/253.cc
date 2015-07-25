/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static uint8 chrlo[8], chrhi[8], prg[2], mirr, vlock;
static int32 IRQa, IRQCount, IRQLatch, IRQClock;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;
static uint8 *CHRRAM = NULL;
static uint32 CHRRAMSIZE;

static SFORMAT StateRegs[] = {{chrlo, 8, "CHRL"},     {chrhi, 8, "CHRH"},
                              {prg, 2, "PRGR"},       {&mirr, 1, "MIRR"},
                              {&vlock, 1, "VLCK"},    {&IRQa, 4, "IRQA"},
                              {&IRQCount, 4, "IRQC"}, {&IRQLatch, 4, "IRQL"},
                              {&IRQClock, 4, "IRQK"}, {0}};

static void Sync() {
  uint8 i;
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setprg8(0x8000, prg[0]);
  fceulib__.cart->setprg8(0xa000, prg[1]);
  fceulib__.cart->setprg8(0xc000, ~1);
  fceulib__.cart->setprg8(0xe000, ~0);
  for (i = 0; i < 8; i++) {
    uint32 chr = chrlo[i] | (chrhi[i] << 8);
    if (chrlo[i] == 0xc8) {
      vlock = 0;
      continue;
    } else if (chrlo[i] == 0x88) {
      vlock = 1;
      continue;
    }
    if (((chrlo[i] == 4) || (chrlo[i] == 5)) && !vlock)
      fceulib__.cart->setchr1r(0x10, i << 10, chr & 1);
    else
      fceulib__.cart->setchr1(i << 10, chr);
  }
  switch (mirr) {
    case 0: fceulib__.cart->setmirror(MI_V); break;
    case 1: fceulib__.cart->setmirror(MI_H); break;
    case 2: fceulib__.cart->setmirror(MI_0); break;
    case 3: fceulib__.cart->setmirror(MI_1); break;
  }
}

static DECLFW(M253Write) {
  if ((A >= 0xB000) && (A <= 0xE00C)) {
    uint8 ind = ((((A & 8) | (A >> 8)) >> 3) + 2) & 7;
    uint8 sar = A & 4;
    chrlo[ind] = (chrlo[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
    if (A & 4) chrhi[ind] = V >> 4;
    Sync();
  } else
    switch (A) {
      case 0x8010:
        prg[0] = V;
        Sync();
        break;
      case 0xA010:
        prg[1] = V;
        Sync();
        break;
      case 0x9400:
        mirr = V & 3;
        Sync();
        break;
      case 0xF000:
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        IRQLatch &= 0xF0;
        IRQLatch |= V & 0xF;
        break;
      case 0xF004:
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        IRQLatch &= 0x0F;
        IRQLatch |= V << 4;
        break;
      case 0xF008:
        fceulib__.X->IRQEnd(FCEU_IQEXT);
        IRQClock = 0;
        IRQCount = IRQLatch;
        IRQa = V & 2;
        break;
    }
}

static void M253Power(FC *fc) {
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M253Write);
}

static void M253Close(FC *fc) {
  free(WRAM);
  free(CHRRAM);
  WRAM = CHRRAM = nullptr;
}

static void M253IRQ(int a) {
  static constexpr int LCYCS = 341;
  if (IRQa) {
    IRQClock += a * 3;
    if (IRQClock >= LCYCS) {
      while (IRQClock >= LCYCS) {
        IRQClock -= LCYCS;
        IRQCount++;
        if (IRQCount & 0x100) {
          fceulib__.X->IRQBegin(FCEU_IQEXT);
          IRQCount = IRQLatch;
        }
      }
    }
  }
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper253_Init(CartInfo *info) {
  info->Power = M253Power;
  info->Close = M253Close;
  fceulib__.X->MapIRQHook = M253IRQ;
  fceulib__.fceu->GameStateRestore = StateRestore;

  CHRRAMSIZE = 2048;
  CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSIZE);
  fceulib__.cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
  fceulib__.state->AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = WRAMSIZE;
  }

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
