/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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

static uint8 cregs[4], pregs[2];
static uint8 IRQCount, IRQa;

static SFORMAT StateRegs[] = {{cregs, 4, "CREG"},
                              {pregs, 2, "PREG"},
                              {&IRQa, 1, "IRQA"},
                              {&IRQCount, 1, "IRQC"},
                              {0}};

static void Sync() {
  fceulib__.cart->setprg8(0x8000, pregs[0]);
  fceulib__.cart->setprg8(0xa000, pregs[1]);
  fceulib__.cart->setprg8(0xc000, ~1);
  fceulib__.cart->setprg8(0xe000, ~0);
  fceulib__.cart->setchr2(0x0000, cregs[0]);
  fceulib__.cart->setchr2(0x0800, cregs[1]);
  fceulib__.cart->setchr2(0x1000, cregs[2]);
  fceulib__.cart->setchr2(0x1800, cregs[3]);
}

static DECLFW(M91Write0) {
  cregs[A & 3] = V;
  Sync();
}

static DECLFW(M91Write1) {
  switch (A & 3) {
    case 0:
    case 1:
      pregs[A & 1] = V;
      Sync();
      break;
    case 2:
      IRQa = IRQCount = 0;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
    case 3:
      IRQa = 1;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
  }
}

static void M91Power() {
  Sync();
  fceulib__.fceu->SetWriteHandler(0x6000, 0x6fff, M91Write0);
  fceulib__.fceu->SetWriteHandler(0x7000, 0x7fff, M91Write1);
  fceulib__.fceu->SetReadHandler(0x8000, 0xffff, Cart::CartBR);
}

static void M91IRQHook() {
  if (IRQCount < 8 && IRQa) {
    IRQCount++;
    if (IRQCount >= 8) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
  }
}

static void StateRestore(int version) {
  Sync();
}

void Mapper91_Init(CartInfo *info) {
  info->Power = M91Power;
  fceulib__.ppu->GameHBIRQHook = M91IRQHook;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
