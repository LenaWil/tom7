/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2011 CaH4e3
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

static uint8 reg, mirr;

static SFORMAT StateRegs[] = {{&reg, 1, "REGS"}, {&mirr, 1, "MIRR"}, {0}};

static void Sync() {
  fceulib__.cart->setprg16(0x8000, reg);
  fceulib__.cart->setprg16(0xc000, ~0);
  fceulib__.cart->setmirror(mirr);
  fceulib__.cart->setchr8(0);
}

static DECLFW(UNLKS7013BLoWrite) {
  reg = V;
  Sync();
}

static DECLFW(UNLKS7013BHiWrite) {
  mirr = (V & 1) ^ 1;
  Sync();
}

static void UNLKS7013BPower() {
  reg = 0;
  mirr = 0;
  Sync();
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, UNLKS7013BLoWrite);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, UNLKS7013BHiWrite);
}

static void UNLKS7013BReset() {
  reg = 0;
  Sync();
}

static void StateRestore(int version) {
  Sync();
}

void UNLKS7013B_Init(CartInfo *info) {
  info->Power = UNLKS7013BPower;
  info->Reset = UNLKS7013BReset;

  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
