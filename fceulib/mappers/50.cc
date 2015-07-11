/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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


static void Mapper50IRQ(int a) {
  if (fceulib__.ines->iNESIRQa) {
    if (fceulib__.ines->iNESIRQCount<4096) {
      fceulib__.ines->iNESIRQCount+=a;
    } else {
      fceulib__.ines->iNESIRQa=0;
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
  }
}

static void M50Restore(int version) {
  fceulib__.cart->setprg8(0xc000,mapbyte1[0]);
}

static DECLFW(M50W) {
  if ((A&0xD060)==0x4020) {
    if (A&0x100) {
      fceulib__.ines->iNESIRQa=V&1;
      if (!fceulib__.ines->iNESIRQa) fceulib__.ines->iNESIRQCount=0;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
    } else {
      V=((V&1)<<2)|((V&2)>>1)|((V&4)>>1)|(V&8);
      mapbyte1[0]=V;
      fceulib__.cart->setprg8(0xc000,V);
    }
  }
}

void Mapper50_init(void) {
  fceulib__.fceu->SetWriteHandler(0x4020,0x5fff,M50W);
  fceulib__.fceu->SetReadHandler(0x6000,0xffff,Cart::CartBR);
  fceulib__.ines->MapStateRestore=M50Restore;
  fceulib__.X->MapIRQHook=Mapper50IRQ;

  fceulib__.cart->setprg8(0x6000,0xF);
  fceulib__.cart->setprg8(0x8000,0x8);
  fceulib__.cart->setprg8(0xa000,0x9);
  fceulib__.cart->setprg8(0xc000,0x0);
  fceulib__.cart->setprg8(0xe000,0xB);
}

