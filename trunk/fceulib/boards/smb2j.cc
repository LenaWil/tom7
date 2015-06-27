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
 * Super Mario Bros 2 J alt version
 * as well as "Voleyball" FDS conversion, bank layot is similar but no bankswitching and CHR ROM present
 *
 * mapper seems wrongly researched by me ;( it should be mapper 43 modification
 */

#include "mapinc.h"

static uint8 prg, IRQa;
static uint16 IRQCount;

static SFORMAT StateRegs[]=
{
  {&prg, 1, "PRG"},
  {&IRQa, 1, "IRQA"},
  {&IRQCount, 2, "IRQC"},
  {0}
};

static void Sync(void)
{
  fceulib__cart.setprg4r(1,0x5000,1);
  fceulib__cart.setprg8r(1,0x6000,1);
  fceulib__cart.setprg32(0x8000,prg);
  fceulib__cart.setchr8(0);
}

static DECLFW(UNLSMB2JWrite)
{
  if(A==0x4022)
  {
    prg=V&1;
    Sync();
  }
  if(A==0x4122)
  {
    IRQa=V;
    IRQCount=0;
    X.IRQEnd(FCEU_IQEXT);
  }
}

static void UNLSMB2JPower(void)
{
  prg=~0;
  Sync();
  fceulib__fceu.SetReadHandler(0x5000,0x7FFF,Cart::CartBR);
  fceulib__fceu.SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fceulib__fceu.SetWriteHandler(0x4020,0xffff,UNLSMB2JWrite);
}

static void UNLSMB2JReset(void)
{
  prg=~0;
  Sync();
}

static void UNLSMB2JIRQHook(int a)
{
  if(IRQa)
  {
    IRQCount+=a*3;
    if((IRQCount>>12)==IRQa)
      X.IRQBegin(FCEU_IQEXT);
  }
}

static void StateRestore(int version)
{
  Sync();
}

void UNLSMB2J_Init(CartInfo *info)
{
  info->Reset=UNLSMB2JReset;
  info->Power=UNLSMB2JPower;
  X.MapIRQHook=UNLSMB2JIRQHook;
  fceulib__fceu.GameStateRestore=StateRestore;
  AddExState(&StateRegs, ~0, 0, 0);
}
