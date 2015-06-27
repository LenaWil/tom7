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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "mapinc.h"

static uint8 reg;

static SFORMAT StateRegs[]=
{
  {&reg, 1, "REGS"},
  {0}
};

static void Sync(void)
{
  fceulib__cart.setprg16(0x8000, 0);
  fceulib__cart.setprg16(0xc000,~0);
  fceulib__cart.setchr8(0);
}

static DECLFW(M170ProtW)
{
  reg = V << 1 & 0x80;
}

static DECLFR(M170ProtR)
{
  return reg | (X.DB & 0x7F);
}

static void M170Power(void)
{
  Sync();
  fceulib__fceu.SetWriteHandler(0x6502,0x6502,M170ProtW);
  fceulib__fceu.SetWriteHandler(0x7000,0x7000,M170ProtW);
  fceulib__fceu.SetReadHandler(0x7001,0x7001,M170ProtR);
  fceulib__fceu.SetReadHandler(0x7777,0x7777,M170ProtR);
  fceulib__fceu.SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
}

static void StateRestore(int version)
{
  Sync();
}

void Mapper170_Init(CartInfo *info)
{
  info->Power=M170Power;
  fceulib__fceu.GameStateRestore=StateRestore;
  AddExState(&StateRegs, ~0, 0, 0);
}
