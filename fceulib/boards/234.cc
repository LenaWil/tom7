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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "mapinc.h"

static uint8 bank, preg;
static SFORMAT StateRegs[] =
{
	{ &bank, 1, "BANK" },
	{ &preg, 1, "PREG" },
	{ 0 }
};

static void Sync(void) {
  if (bank & 0x40) {
    fceulib__cart.setprg32(0x8000, (bank & 0xE) | (preg & 1));
    fceulib__cart.setchr8(((bank & 0xE) << 2) | ((preg >> 4) & 7));
  } else {
    fceulib__cart.setprg32(0x8000, bank & 0xF);
    fceulib__cart.setchr8(((bank & 0xF) << 2) | ((preg >> 4) & 3));
  }
  fceulib__cart.setmirror((bank >> 7) ^ 1);
}

DECLFR(M234ReadBank) {
  uint8 r = Cart::CartBR(A);
  if (!bank) {
    bank = r;
    Sync();
  }
  return r;
}

DECLFR(M234ReadPreg) {
  uint8 r = Cart::CartBR(A);
  preg = r;
  Sync();
  return r;
}

static void M234Reset(void) {
  bank = preg = 0;
  Sync();
}

static void M234Power(void) {
  M234Reset();
  fceulib__fceu.SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__fceu.SetReadHandler(0xFF80, 0xFF9F, M234ReadBank);
  fceulib__fceu.SetReadHandler(0xFFE8, 0xFFF7, M234ReadPreg);
}

static void StateRestore(int version) {
	Sync();
}

void Mapper234_Init(CartInfo *info) {
	info->Power = M234Power;
	info->Reset = M234Reset;
	AddExState(&StateRegs, ~0, 0, 0);
	fceulib__fceu.GameStateRestore = StateRestore;
}
