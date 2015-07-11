/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
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
 * Gimmick Bootleg (VRC4 mapper)
 */

#include "mapinc.h"

static uint8 prg[4];
static uint8 chr[8];
static uint8 IRQCount;
static uint8 IRQPre;
static uint8 IRQa;

static SFORMAT StateRegs[] = {
  {prg, 4, "PRG"},
  {chr, 8, "CHR"},
  {&IRQCount, 1, "IRQC"},
  {&IRQPre, 1, "IRQP"},
  {&IRQa, 1, "IRQA"},
  {0}
};

static void SyncPrg(void) {
  fceulib__.cart->setprg8(0x6000,0);
  fceulib__.cart->setprg8(0x8000,prg[0]);
  fceulib__.cart->setprg8(0xA000,prg[1]);
  fceulib__.cart->setprg8(0xC000,prg[2]);
  fceulib__.cart->setprg8(0xE000,~0);
}

static void SyncChr(void) {
  for (int i = 0; i<8; i++)
    fceulib__.cart->setchr1(i<<10,chr[i]);
}

static void StateRestore(int version) {
  SyncPrg();
  SyncChr();
}

static DECLFW(M183Write) {
  if (((A&0xF80C)>=0xB000)&&((A&0xF80C)<=0xE00C)) {
    int index=(((A>>11)-6)|(A>>3))&7;
    chr[index]=(chr[index]&(0xF0>>(A&4)))|((V&0x0F)<<(A&4));
    SyncChr();
  } else { 
    switch (A&0xF80C) {
    case 0x8800: prg[0]=V; SyncPrg(); break;
    case 0xA800: prg[1]=V; SyncPrg(); break;
    case 0xA000: prg[2]=V; SyncPrg(); break;
    case 0x9800:
      switch (V&3) {
      case 0: fceulib__.cart->setmirror(MI_V); break;
      case 1: fceulib__.cart->setmirror(MI_H); break;
      case 2: fceulib__.cart->setmirror(MI_0); break;
      case 3: fceulib__.cart->setmirror(MI_1); break;
      }
      break;
    case 0xF000: IRQCount=((IRQCount&0xF0)|(V&0xF)); break;
    case 0xF004: IRQCount=((IRQCount&0x0F)|((V&0xF)<<4)); break;
    case 0xF008: IRQa=V; if (!V)IRQPre=0; fceulib__.X->IRQEnd(FCEU_IQEXT); break;
    case 0xF00C: IRQPre=16; break;
    }
  }
}

static void M183IRQCounter(void) {
  if (IRQa) {
    IRQCount++;
    if ((IRQCount-IRQPre)==238)
      fceulib__.X->IRQBegin(FCEU_IQEXT);
  }
}

static void M183Power(void) {
  IRQPre=IRQCount=IRQa=0;
  fceulib__.fceu->SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000,0xFFFF,M183Write);
  fceulib__.fceu->SetReadHandler(0x6000,0x7FFF,Cart::CartBR);
  SyncPrg();
  SyncChr();
}

void Mapper183_Init(CartInfo *info) {
  info->Power=M183Power;
  fceulib__.ppu->GameHBIRQHook=M183IRQCounter;
  fceulib__.fceu->GameStateRestore=StateRestore;
  AddExState(&StateRegs, ~0, 0, 0);
}
