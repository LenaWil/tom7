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

static uint8 bank, preg;
static SFORMAT StateRegs[] = {{&bank, 1, "BANK"}, {&preg, 1, "PREG"}, {0}};

static void Sync() {
  //	uint32 bbank = (bank & 0x18) >> 1;
  uint32 bbank =
      ((bank & 0x10) >> 2) |
      (bank & 8);  // some dumps have bbanks swapped, if swap commands,
  // then all roms can be played, but with some swapped
  // games in menu. if not, some dumps are unplayable
  // make hard dump for both cart types to check
  fceulib__.cart->setprg16(0x8000, bbank | (preg & 3));
  fceulib__.cart->setprg16(0xC000, bbank | 3);
  fceulib__.cart->setchr8(0);
}

static DECLFW(M232WriteBank) {
  bank = V;
  Sync();
}

static DECLFW(M232WritePreg) {
  preg = V;
  Sync();
}

static void M232Power() {
  bank = preg = 0;
  Sync();
  fceulib__.fceu->SetWriteHandler(0x8000, 0xBFFF, M232WriteBank);
  fceulib__.fceu->SetWriteHandler(0xC000, 0xFFFF, M232WritePreg);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
}

static void StateRestore(int version) {
  Sync();
}

void Mapper232_Init(CartInfo *info) {
  info->Power = M232Power;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
  fceulib__.fceu->GameStateRestore = StateRestore;
}
