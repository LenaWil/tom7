/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
 *  Copyright (C) 2009 qeed
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
 * 22 + Contra Reset based custom mapper...
 *
 */

#include "mapinc.h"

static uint8 latche, reset;
static SFORMAT StateRegs[] = {{&reset, 1, "RST"}, {&latche, 1, "LATC"}, {0}};

static void Sync() {
  if (reset) {
    fceulib__.cart->setprg16(0x8000, latche & 7);
    fceulib__.cart->setprg16(0xC000, 7);
    fceulib__.cart->setmirror(MI_V);
  } else {
    uint32 bank = (latche & 0x1F) + 8;
    if (latche & 0x20) {
      fceulib__.cart->setprg16(0x8000, bank);
      fceulib__.cart->setprg16(0xC000, bank);
    } else {
      fceulib__.cart->setprg32(0x8000, bank >> 1);
    }
    fceulib__.cart->setmirror((latche >> 6) & 1);
  }
  fceulib__.cart->setchr8(0);
}

static DECLFW(M230Write) {
  latche = V;
  Sync();
}

static void M230Reset(FC *fc) {
  reset ^= 1;
  Sync();
}

static void M230Power(FC *fc) {
  latche = reset = 0;
  Sync();
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M230Write);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper230_Init(CartInfo *info) {
  info->Power = M230Power;
  info->Reset = M230Reset;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
  fceulib__.fceu->GameStateRestore = StateRestore;
}
