/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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

// ccording to nestopia, BTL_SMB2_C, otherwise known as UNL-SMB2J

#include "mapinc.h"

static uint8 reg;
static uint32 IRQCount, IRQa;

static SFORMAT StateRegs[] = {
    {&IRQCount, 4, "IRQC"}, {&IRQa, 1, "IRQA"}, {&reg, 1, "REG"}, {0}};

static void Sync(void) {
  fceulib__.cart->setprg4(0x5000, 16);  // Only YS-612 advdnced version
  fceulib__.cart->setprg8(0x6000, 2);
  fceulib__.cart->setprg8(0x8000, 1);
  fceulib__.cart->setprg8(0xa000, 0);
  fceulib__.cart->setprg8(0xc000, reg);
  fceulib__.cart->setprg8(0xe000, 9);
  fceulib__.cart->setchr8(0);
}

static DECLFW(M43Write) {
  //  int transo[8]={4,3,4,4,4,7,5,6};
  // According to hardware tests:
  static constexpr int transo[8] = {4, 3, 5, 3, 6, 3, 7, 3};
  switch (A & 0xf1ff) {
    case 0x4022:
      reg = transo[V & 7];
      Sync();
      break;
    case 0x8122:  // hacked version
    case 0x4122:
      IRQa = V & 1;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      IRQCount = 0;
      break;  // original version
  }
}

static void M43Power(void) {
  reg = 0;
  Sync();
  fceulib__.fceu->SetReadHandler(0x5000, 0xffff, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4020, 0xffff, M43Write);
}

static void M43Reset(void) {}

static void M43IRQHook(int a) {
  IRQCount += a;
  if (IRQa)
    if (IRQCount >= 4096) {
      IRQa = 0;
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
}

static void StateRestore(int version) {
  Sync();
}

void Mapper43_Init(CartInfo *info) {
  info->Reset = M43Reset;
  info->Power = M43Power;
  fceulib__.X->MapIRQHook = M43IRQHook;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
