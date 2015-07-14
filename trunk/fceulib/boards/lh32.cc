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
 *
 * FDS Conversion
 *
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
  fceulib__.cart->setprg8(0x6000,reg);
  fceulib__.cart->setprg8(0x8000,~3);
  fceulib__.cart->setprg8(0xa000,~2);
  fceulib__.cart->setprg8r(0x10,0xc000,0);
  fceulib__.cart->setprg8(0xe000,~0);
  fceulib__.cart->setchr8(0);
}

static DECLFW(LH32Write)
{
  reg=V;
  Sync();
}

static void LH32Power(void)
{
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000,0xFFFF,Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0xC000,0xDFFF,Cart::CartBW);
  fceulib__.fceu->SetWriteHandler(0x6000,0x6000,LH32Write);
}

static void LH32Close(void)
{
  if(WRAM)
    free(WRAM);
  WRAM=NULL;
}

static void StateRestore(int version)
{
  Sync();
}

void LH32_Init(CartInfo *info)
{
  info->Power=LH32Power;
  info->Close=LH32Close;

  WRAMSIZE=8192;
  WRAM=(uint8*)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10,WRAM,WRAMSIZE,1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.fceu->GameStateRestore=StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
