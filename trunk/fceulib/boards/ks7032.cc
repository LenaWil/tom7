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

static uint8 reg[8], cmd, IRQa = 0, isirqused = 0;
static int32 IRQCount;

static SFORMAT StateRegs[]=
{
  {&cmd, 1, "CMD"},
  {reg, 8, "REGS"},
  {&IRQa, 1, "IRQA"},
  {&IRQCount, 4, "IRQC"},
  {0}
};

static void Sync(void) {
  fceulib__.cart->setprg8(0x6000,reg[4]);
  fceulib__.cart->setprg8(0x8000,reg[1]);
  fceulib__.cart->setprg8(0xA000,reg[2]);
  fceulib__.cart->setprg8(0xC000,reg[3]);
  fceulib__.cart->setprg8(0xE000,~0);
  fceulib__.cart->setchr8(0);
}

static DECLFW(UNLKS7032Write)
{
//  FCEU_printf("bs %04x %02x\n",A,V);
  switch(A&0xF000)
  {
//    case 0x8FFF: reg[4]=V; Sync(); break;
    case 0x8000: fceulib__.X->IRQEnd(FCEU_IQEXT); IRQCount=(IRQCount&0x000F)|(V&0x0F); isirqused = 1; break;
    case 0x9000: fceulib__.X->IRQEnd(FCEU_IQEXT); IRQCount=(IRQCount&0x00F0)|((V&0x0F)<<4); isirqused = 1; break;
    case 0xA000: fceulib__.X->IRQEnd(FCEU_IQEXT); IRQCount=(IRQCount&0x0F00)|((V&0x0F)<<8); isirqused = 1; break;
    case 0xB000: fceulib__.X->IRQEnd(FCEU_IQEXT); IRQCount=(IRQCount&0xF000)|(V<<12); isirqused = 1; break;
    case 0xC000: if(isirqused) { fceulib__.X->IRQEnd(FCEU_IQEXT); IRQa=1; } break;
    case 0xE000: cmd=V&7; break;
    case 0xF000: reg[cmd]=V; Sync(); break;
  }
}

static void UNLSMB2JIRQHook(int a)
{
  if(IRQa)
  {
    IRQCount+=a;
    if(IRQCount>=0xFFFF)
    {
      IRQa=0;
      IRQCount=0;
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
  }
}

static void UNLKS7032Power(void)
{
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000,0x7FFF,Cart::CartBR);
  fceulib__.fceu->SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4020,0xFFFF,UNLKS7032Write);
}

static void StateRestore(int version)
{
  Sync();
}

void UNLKS7032_Init(CartInfo *info)
{
  info->Power=UNLKS7032Power;
  fceulib__.X->MapIRQHook=UNLSMB2JIRQHook;
  fceulib__.fceu->GameStateRestore=StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
