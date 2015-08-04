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

static uint8 reg[4], IRQa;
static int16 IRQCount, IRQPause;

static int16 Count = 0x0000;

static vector<SFORMAT> StateRegs = {
    {reg, 4, "REGS"}, {&IRQa, 1, "IRQA"}, {&IRQCount, 2, "IRQC"}};

static void Sync() {
  fceulib__.cart->setprg32(0x8000, 0);
  fceulib__.cart->setchr8(0);
}

//#define Count 0x1800
#define Pause 0x010

static DECLFW(UNL3DBlockWrite) {
  switch (A) {
    // 4800 32
    // 4900 37
    // 4a00 01
    // 4e00 18
    case 0x4800: reg[0] = V; break;
    case 0x4900: reg[1] = V; break;
    case 0x4a00: reg[2] = V; break;
    case 0x4e00:
      reg[3] = V;
      IRQCount = Count;
      IRQPause = Pause;
      IRQa = 1;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
  }
}

static void UNL3DBlockPower(FC *fc) {
  Sync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4800, 0x4E00, UNL3DBlockWrite);
}

static void UNL3DBlockReset(FC *fc) {
  Count += 0x10;
  FCEU_printf("Count=%04x\n", Count);
}

static void UNL3DBlockIRQHook(FC *fc, int a) {
  if (IRQa) {
    if (IRQCount > 0) {
      IRQCount -= a;
    } else {
      if (IRQPause > 0) {
        IRQPause -= a;
        fceulib__.X->IRQBegin(FCEU_IQEXT);
      } else {
        IRQCount = Count;
        IRQPause = Pause;
        fceulib__.X->IRQEnd(FCEU_IQEXT);
      }
    }
  }
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void UNL3DBlock_Init(CartInfo *info) {
  info->Power = UNL3DBlockPower;
  info->Reset = UNL3DBlockReset;
  fceulib__.X->MapIRQHook = UNL3DBlockIRQHook;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExVec(StateRegs);
}
