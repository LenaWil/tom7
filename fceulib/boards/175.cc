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

static uint8 reg, delay, mirr;

static SFORMAT StateRegs[] = {{&reg, 1, "REG"}, {&mirr, 1, "MIRR"}, {0}};

static void Sync() {
  fceulib__.cart->setchr8(reg);
  if (!delay) {
    fceulib__.cart->setprg16(0x8000, reg);
    fceulib__.cart->setprg8(0xC000, reg << 1);
  }
  fceulib__.cart->setprg8(0xE000, (reg << 1) + 1);
  fceulib__.cart->setmirror(((mirr & 4) >> 2) ^ 1);
}

static DECLFW(M175Write1) {
  mirr = V;
  delay = 1;
  Sync();
}

static DECLFW(M175Write2) {
  reg = V & 0x0F;
  delay = 1;
  Sync();
}

static DECLFR(M175Read) {
  if (A == 0xFFFC) {
    delay = 0;
    Sync();
  }
  return Cart::CartBR(DECLFR_FORWARD);
}

static void M175Power(FC *fc) {
  reg = mirr = delay = 0;
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, M175Read);
  fceulib__.fceu->SetWriteHandler(0x8000, 0x8000, M175Write1);
  fceulib__.fceu->SetWriteHandler(0xA000, 0xA000, M175Write2);
  Sync();
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper175_Init(CartInfo *info) {
  info->Power = M175Power;
  fceulib__.fceu->GameStateRestore = StateRestore;

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
