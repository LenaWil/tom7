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


static DECLFW(Mapper40_write) {
  switch(A&0xe000) {
  case 0x8000:fceulib__.ines->iNESIRQa=0;fceulib__.ines->iNESIRQCount=0;fceulib__.X->IRQEnd(FCEU_IQEXT);break;
  case 0xa000:fceulib__.ines->iNESIRQa=1;break;
  case 0xe000:ROM_BANK8(0xc000,V&7);break;
  }
}

static void Mapper40IRQ(int a) {
  if(fceulib__.ines->iNESIRQa) {
    if(fceulib__.ines->iNESIRQCount<4096) {
      fceulib__.ines->iNESIRQCount+=a;
    } else {
      fceulib__.ines->iNESIRQa=0;
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    }
  }
}

void Mapper40_init(void)
{
  ROM_BANK8(0x6000,(~0)-1);
  ROM_BANK8(0x8000,(~0)-3);
  ROM_BANK8(0xa000,(~0)-2);
  fceulib__.fceu->SetWriteHandler(0x8000,0xffff,Mapper40_write);
  fceulib__.fceu->SetReadHandler(0x6000,0x7fff,Cart::CartBR);
  fceulib__.X->MapIRQHook=Mapper40IRQ;
}


