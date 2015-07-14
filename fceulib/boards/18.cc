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

static uint8 preg[4], creg[8];
static uint8 IRQa, mirr;
static int32 IRQCount, IRQLatch;

static SFORMAT StateRegs[]=
{
  {preg, 4, "PREG"},
  {creg, 8, "CREG"},
  {&mirr, 1, "MIRR"},
  {&IRQa, 1, "IRQA"},
  {&IRQCount, 4, "IRQC"},
  {&IRQLatch, 4, "IRQL"},
  {0}
};

static void Sync(void) {
  for(int i=0; i<8; i++) fceulib__.cart->setchr1(i<<10,creg[i]);
  fceulib__.cart->setprg8(0x8000,preg[0]);
  fceulib__.cart->setprg8(0xA000,preg[1]);
  fceulib__.cart->setprg8(0xC000,preg[2]);
  fceulib__.cart->setprg8(0xE000,~0);
  if(mirr & 2)
    fceulib__.cart->setmirror(MI_0);
  else
    fceulib__.cart->setmirror(mirr & 1);
}

static DECLFW(M18WriteIRQ)
{
  switch(A & 0xF003) {
    case 0xE000: IRQLatch&=0xFFF0; IRQLatch|=(V&0x0f)<<0x0;break;
    case 0xE001: IRQLatch&=0xFF0F; IRQLatch|=(V&0x0f)<<0x4; break;
    case 0xE002: IRQLatch&=0xF0FF; IRQLatch|=(V&0x0f)<<0x8; break;
    case 0xE003: IRQLatch&=0x0FFF; IRQLatch|=(V&0x0f)<<0xC; break;
    case 0xF000: IRQCount=IRQLatch; break;
    case 0xF001: IRQa=V&1; fceulib__.X->IRQEnd(FCEU_IQEXT); break;
    case 0xF002: mirr = V&3; Sync(); break;
  }
}

static DECLFW(M18WritePrg)
{
  uint32 i = ((A >> 1) & 1)|((A - 0x8000) >> 11);
  preg[i] &= (0xF0) >> ((A & 1) << 2);
  preg[i] |= (V & 0xF) << ((A & 1) << 2);
  Sync();
}

static DECLFW(M18WriteChr)
{
  uint32 i = ((A >> 1) & 1)|((A - 0xA000) >> 11);
  creg[i] &= (0xF0) >> ((A & 1) << 2);
  creg[i] |= (V & 0xF) << ((A & 1) << 2);
  Sync();
}

static void M18Power(void)
{
  preg[0] = 0;
  preg[1] = 1;
  preg[2] = ~1;
  preg[3] = ~0;
  Sync();
  fceulib__.fceu->SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000,0x9FFF,M18WritePrg);
  fceulib__.fceu->SetWriteHandler(0xA000,0xDFFF,M18WriteChr);
  fceulib__.fceu->SetWriteHandler(0xE000,0xFFFF,M18WriteIRQ);
}

static void M18IRQHook(int a)
{
  if(IRQa && IRQCount)
  {
    IRQCount-=a;
    if(IRQCount<=0)
    {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      IRQCount=0;
      IRQa=0;
    }
  }
}

static void StateRestore(int version)
{
  Sync();
}

void Mapper18_Init(CartInfo *info)
{
  info->Power=M18Power;
  fceulib__.X->MapIRQHook=M18IRQHook;
  fceulib__.fceu->GameStateRestore=StateRestore;

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}

