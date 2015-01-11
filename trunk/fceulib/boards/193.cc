/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static uint8 reg[8];
static uint8 mirror, cmd, bank;

static SFORMAT StateRegs[]=
{
  {&cmd, 1, "CMD"},
  {&mirror, 1, "MIRR"},
  {&bank, 1, "BANK"},
  {reg, 8, "REGS"},
  {0}
};

static void Sync(void)
{
  fceulib__cart.setmirror(mirror^1);
  fceulib__cart.setprg8(0x8000,reg[3]);
  fceulib__cart.setprg8(0xA000,0xD);
  fceulib__cart.setprg8(0xC000,0xE);
  fceulib__cart.setprg8(0xE000,0xF);
  fceulib__cart.setchr4(0x0000,reg[0]>>2);
  fceulib__cart.setchr2(0x1000,reg[1]>>1);
  fceulib__cart.setchr2(0x1800,reg[2]>>1);
}

static DECLFW(M193Write)
{
  reg[A&3]=V;
  Sync();
}

static void M193Power(void)
{
  bank=0;
  Sync();
  SetWriteHandler(0x6000,0x6003,M193Write);
  SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  SetWriteHandler(0x8000,0xFFFF,Cart::CartBW);
}

static void M193Reset(void)
{
}

static void StateRestore(int version)
{
  Sync();
}

void Mapper193_Init(CartInfo *info)
{
  info->Reset=M193Reset;
  info->Power=M193Power;
  GameStateRestore=StateRestore;
  AddExState(&StateRegs, ~0, 0, 0);
}
