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

static uint8 latch;
static writefunc old4016;

static SFORMAT StateRegs[] = {{&latch, 1, "LATC"}, {0}};

static void Sync() {
  fceulib__.cart->setchr8((latch >> 2) & 1);
  fceulib__.cart->setprg32(0x8000, 0);
  fceulib__.cart->setprg8(0x8000, latch & 4); /* Special for VS Gumshoe */
}

static DECLFW(M99Write) {
  latch = V;
  Sync();
  old4016(DECLFW_FORWARD);
}

static void M99Power() {
  latch = 0;
  Sync();
  old4016 = fceulib__.fceu->GetWriteHandler(0x4016);
  fceulib__.fceu->SetWriteHandler(0x4016, 0x4016, M99Write);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
}

static void StateRestore(int version) {
  Sync();
}

void Mapper99_Init(CartInfo *info) {
  info->Power = M99Power;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
