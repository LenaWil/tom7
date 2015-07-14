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

static uint8 reg;

static SFORMAT StateRegs[] = {{&reg, 1, "REG"}, {0}};

static void Sync() {
  fceulib__.cart->setprg8(0x6000, reg);
  fceulib__.cart->setprg32(0x8000, ~0);
  fceulib__.cart->setchr8(0);
}

static DECLFW(M108Write) {
  reg = V;
  Sync();
}

static void M108Power() {
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0x8FFF, M108Write);  // regular 108
  fceulib__.fceu->SetWriteHandler(0xF000, 0xFFFF,
                                  M108Write);  // simplified Kaiser BB Hack
}

static void StateRestore(int version) {
  Sync();
}

void Mapper108_Init(CartInfo *info) {
  info->Power = M108Power;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
