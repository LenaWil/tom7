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


#define suntoggle mapbyte1[0]

static DECLFW(Mapper67_write) {
  A&=0xF800;
  if((A&0x800) && A<=0xb800) {
    VROM_BANK2((A-0x8800)>>1,V);
  }
  else switch(A) {
    case 0xc800:
    case 0xc000:
      if(!suntoggle) {
	fceulib__.ines->iNESIRQCount&=0xFF;
	fceulib__.ines->iNESIRQCount|=V<<8;
      } else {
	fceulib__.ines->iNESIRQCount&=0xFF00;
	fceulib__.ines->iNESIRQCount|=V;
      }
      suntoggle^=1;
      break;
    case 0xd800:
      suntoggle=0;
      fceulib__.ines->iNESIRQa=V&0x10;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;

    case 0xe800:
      switch(V&3) {
      case 0:fceulib__.ines->MIRROR_SET2(1);break;
      case 1:fceulib__.ines->MIRROR_SET2(0);break;
      case 2:fceulib__.ines->onemir(0);break;
      case 3:fceulib__.ines->onemir(1);break;
      }
      break;
    case 0xf800:
      ROM_BANK16(0x8000,V);
      break;
    }
}
static void SunIRQHook(int a) {
  if(fceulib__.ines->iNESIRQa) {
    fceulib__.ines->iNESIRQCount-=a;
    if(fceulib__.ines->iNESIRQCount<=0) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      fceulib__.ines->iNESIRQa=0;
      fceulib__.ines->iNESIRQCount=0xFFFF;
    }
  }
}

void Mapper67_init(void) {
  fceulib__.fceu->SetWriteHandler(0x8000,0xffff,Mapper67_write);
  fceulib__.X->MapIRQHook=SunIRQHook;
}
