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
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

static uint8 reg[4];

static SFORMAT StateRegs[] = {{reg, 4, "REGS"}, {0}};

static void Sync() {
  fceulib__.cart->setprg2(0x6000, reg[0]);
  fceulib__.cart->setprg2(0x6800, reg[1]);
  fceulib__.cart->setprg2(0x7000, reg[2]);
  fceulib__.cart->setprg2(0x7800, reg[3]);

  fceulib__.cart->setprg2(0x8000, 15);
  fceulib__.cart->setprg2(0x8800, 14);
  fceulib__.cart->setprg2(0x9000, 13);
  fceulib__.cart->setprg2(0x9800, 12);
  fceulib__.cart->setprg2(0xa000, 11);
  fceulib__.cart->setprg2(0xa800, 10);
  fceulib__.cart->setprg2(0xb000, 9);
  fceulib__.cart->setprg2(0xb800, 8);

  fceulib__.cart->setprg2(0xc000, 7);
  fceulib__.cart->setprg2(0xc800, 6);
  fceulib__.cart->setprg2(0xd000, 5);
  fceulib__.cart->setprg2(0xd800, 4);
  fceulib__.cart->setprg2(0xe000, 3);
  fceulib__.cart->setprg2(0xe800, 2);
  fceulib__.cart->setprg2(0xf000, 1);
  fceulib__.cart->setprg2(0xf800, 0);

  fceulib__.cart->setchr8(0);
}

static DECLFW(UNLKS7031Write) {
  reg[(A >> 11) & 3] = V;
  Sync();
}

static void UNLKS7031Power(FC *fc) {
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, UNLKS7031Write);
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void UNLKS7031_Init(CartInfo *info) {
  info->Power = UNLKS7031Power;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
