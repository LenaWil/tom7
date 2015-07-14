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

#include "mapinc.h"

static uint16 addrreg;
static uint8 datareg;
static uint8 busy;
static SFORMAT StateRegs[] = {
    {&addrreg, 2, "AREG"}, {&datareg, 1, "DREG"}, {&busy, 1, "BUSY"}, {0}};

static void Sync(void) {
  uint16 base = ((addrreg & 0x60) >> 2) | ((addrreg & 0x100) >> 3);
  fceulib__.cart->setprg16(0x8000, (datareg & 7) | base);
  fceulib__.cart->setprg16(0xC000, 7 | base);
  fceulib__.cart->setmirror(((addrreg & 2) >> 1) ^ 1);
}

static DECLFW(BMCT262Write) {
  if (busy || (A == 0x8000))
    datareg = V;
  else {
    addrreg = A;
    busy = 1;
  }
  Sync();
}

static void BMCT262Power(void) {
  fceulib__.cart->setchr8(0);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, BMCT262Write);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  busy = 0;
  addrreg = 0;
  datareg = 0xff;
  Sync();
}

static void BMCT262Reset(void) {
  busy = 0;
  addrreg = 0;
  datareg = 0;
  Sync();
}

static void BMCT262Restore(int version) {
  Sync();
}

void BMCT262_Init(CartInfo *info) {
  info->Power = BMCT262Power;
  info->Reset = BMCT262Reset;
  fceulib__.fceu->GameStateRestore = BMCT262Restore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
