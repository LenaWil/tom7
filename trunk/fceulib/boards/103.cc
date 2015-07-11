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

static uint8 reg0, reg1, reg2;
static uint8 *WRAM=NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[]=
{
  {&reg0, 1, "REG0"},
  {&reg1, 1, "REG1"},
  {&reg2, 1, "REG2"},
  {0}
};

static void Sync(void) {
  fceulib__.cart->setchr8(0);
  fceulib__.cart->setprg8(0x8000,0xc);
  fceulib__.cart->setprg8(0xe000,0xf);
  if(reg2&0x10) {
    fceulib__.cart->setprg8(0x6000,reg0);
    fceulib__.cart->setprg8(0xa000,0xd);
    fceulib__.cart->setprg8(0xc000,0xe);
  } else {
    fceulib__.cart->setprg8r(0x10,0x6000,0);
    fceulib__.cart->setprg4(0xa000,(0xd<<1));
    fceulib__.cart->setprg2(0xb000,(0xd<<2)+2);
    fceulib__.cart->setprg2r(0x10,0xb800,4);
    fceulib__.cart->setprg2r(0x10,0xc000,5);
    fceulib__.cart->setprg2r(0x10,0xc800,6);
    fceulib__.cart->setprg2r(0x10,0xd000,7);
    fceulib__.cart->setprg2(0xd800,(0xe<<2)+3);
  }
  fceulib__.cart->setmirror(reg1^1);
}

static DECLFW(M103RamWrite0)
{
  WRAM[A&0x1FFF]=V;
}

static DECLFW(M103RamWrite1)
{
  WRAM[0x2000+((A-0xB800)&0x1FFF)]=V;
}

static DECLFW(M103Write0)
{
  reg0=V&0xf;
  Sync();
}

static DECLFW(M103Write1)
{
  reg1=(V>>3)&1;
  Sync();
}

static DECLFW(M103Write2)
{
  reg2=V;
  Sync();
}

static void M103Power(void)
{
  reg0=reg1=0; reg2=0;
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000,0x7FFF,Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000,0x7FFF,M103RamWrite0);
  fceulib__.fceu->SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0xB800,0xD7FF,M103RamWrite1);
  fceulib__.fceu->SetWriteHandler(0x8000,0x8FFF,M103Write0);
  fceulib__.fceu->SetWriteHandler(0xE000,0xEFFF,M103Write1);
  fceulib__.fceu->SetWriteHandler(0xF000,0xFFFF,M103Write2);
}

static void M103Close(void)
{
  if(WRAM)
    free(WRAM);
  WRAM=NULL;
}

static void StateRestore(int version)
{
  Sync();
}

void Mapper103_Init(CartInfo *info)
{
  info->Power=M103Power;
  info->Close=M103Close;
  fceulib__.fceu->GameStateRestore=StateRestore;

  WRAMSIZE=16384;
  WRAM=(uint8*)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10,WRAM,WRAMSIZE,1);
  AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  AddExState(&StateRegs, ~0, 0, 0);
}
