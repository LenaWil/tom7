/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO
 *  Copyright (C) 2002 Xodnizel
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

static uint8 reg, ppulatch;

static SFORMAT StateRegs[]= {
  {&reg, 1, "REG"},
  {&ppulatch, 1, "PPUL"},
  {0}
};

static void Sync(void) {
  fceulib__cart.setmirror(MI_0);
  fceulib__cart.setprg32(0x8000,reg & 3);
  fceulib__cart.setchr4(0x0000,(reg & 4) | ppulatch);
  fceulib__cart.setchr4(0x1000,(reg & 4) | 3);
}

static DECLFW(M96Write) {
  reg = V;
  Sync();
}

static void M96Hook(uint32 A) {
  if ((A & 0x3000) == 0x2000) {
    ppulatch = (A>>8) & 3;
    Sync();
  }
}

static void M96Power(void) {
  reg = ppulatch = 0;
  Sync();
  fceulib__fceu.SetReadHandler(0x8000,0xffff,Cart::CartBR);
  fceulib__fceu.SetWriteHandler(0x8000,0xffff,M96Write);
}

static void StateRestore(int version) {
  Sync();
}

void Mapper96_Init(CartInfo *info) {
  info->Power=M96Power;
  fceulib__ppu.PPU_hook=M96Hook;
  fceulib__fceu.GameStateRestore=StateRestore;
  AddExState(&StateRegs, ~0, 0, 0);
}

