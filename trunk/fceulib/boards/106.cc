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
 */

#include "mapinc.h"

static uint8 reg[16], IRQa;
static uint32 IRQCount;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] = {
    {&IRQa, 1, "IRQA"}, {&IRQCount, 4, "IRQC"}, {reg, 16, "REGS"}, {0}};

static void Sync() {
  fceulib__.cart->setchr1(0x0000, reg[0] & 0xfe);
  fceulib__.cart->setchr1(0x0400, reg[1] | 1);
  fceulib__.cart->setchr1(0x0800, reg[2] & 0xfe);
  fceulib__.cart->setchr1(0x0c00, reg[3] | 1);
  fceulib__.cart->setchr1(0x1000, reg[4]);
  fceulib__.cart->setchr1(0x1400, reg[5]);
  fceulib__.cart->setchr1(0x1800, reg[6]);
  fceulib__.cart->setchr1(0x1c00, reg[7]);
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setprg8(0x8000, (reg[0x8] & 0xf) | 0x10);
  fceulib__.cart->setprg8(0xA000, (reg[0x9] & 0x1f));
  fceulib__.cart->setprg8(0xC000, (reg[0xa] & 0x1f));
  fceulib__.cart->setprg8(0xE000, (reg[0xb] & 0xf) | 0x10);
  fceulib__.cart->setmirror((reg[0xc] & 1) ^ 1);
}

static DECLFW(M106Write) {
  A &= 0xF;
  switch (A) {
    case 0xD:
      IRQa = 0;
      IRQCount = 0;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xE: IRQCount = (IRQCount & 0xFF00) | V; break;
    case 0xF:
      IRQCount = (IRQCount & 0x00FF) | (V << 8);
      IRQa = 1;
      break;
    default:
      reg[A] = V;
      Sync();
      break;
  }
}

static void M106Power(FC *fc) {
  reg[8] = reg[9] = reg[0xa] = reg[0xb] = -1;
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M106Write);
}

static void M106Reset(FC *fc) {}

static void M106Close(FC *fc) {
  free(WRAM);
  WRAM = nullptr;
}

void M106CpuHook(int a) {
  if (IRQa) {
    IRQCount += a;
    if (IRQCount > 0x10000) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      IRQa = 0;
    }
  }
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper106_Init(CartInfo *info) {
  info->Reset = M106Reset;
  info->Power = M106Power;
  info->Close = M106Close;
  fceulib__.X->MapIRQHook = M106CpuHook;
  fceulib__.fceu->GameStateRestore = StateRestore;

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
