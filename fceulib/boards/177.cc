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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "mapinc.h"

static uint8 reg;

static uint8 *WRAM=NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[]=
{
  {&reg, 1, "REG"},
  {0}
};

static void Sync(void)
{
  fceulib__cart.setchr8(0);
  fceulib__cart.setprg8r(0x10,0x6000,0);
  fceulib__cart.setprg32(0x8000,reg&0x1f);
  fceulib__cart.setmirror(((reg&0x20)>>5)^1);
}

static DECLFW(M177Write)
{
  reg=V;
  Sync();
}

static void M177Power(void)
{
  reg=0;
  Sync();
  fceulib__fceu.SetReadHandler(0x6000,0x7fff,Cart::CartBR);
  fceulib__fceu.SetWriteHandler(0x6000,0x7fff,Cart::CartBW);
  fceulib__fceu.SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fceulib__fceu.SetWriteHandler(0x8000,0xFFFF,M177Write);
}

static void M177Close(void)
{
  if(WRAM)
    free(WRAM);
  WRAM=NULL;
}

static void StateRestore(int version)
{
  Sync();
}

void Mapper177_Init(CartInfo *info)
{
  info->Power=M177Power;
  info->Close=M177Close;
  fceulib__fceu.GameStateRestore=StateRestore;

  WRAMSIZE=8192;
  WRAM=(uint8*)FCEU_gmalloc(WRAMSIZE);
  fceulib__cart.SetupCartPRGMapping(0x10,WRAM,WRAMSIZE,1);
  AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  if(info->battery)
  {
    info->SaveGame[0]=WRAM;
    info->SaveGameLen[0]=WRAMSIZE;
  }

  AddExState(&StateRegs, ~0, 0, 0);
}