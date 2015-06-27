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


static DECLFW(Mapper42_write) {
// FCEU_printf("%04x:%04x\n",A,V);
 switch(A&0xe003) {
  case 0x8000:VROM_BANK8(V);break;
  case 0xe000:mapbyte1[0]=V;ROM_BANK8(0x6000,V&0xF);break;
  case 0xe001:fceulib__ines.MIRROR_SET((V>>3)&1);break;
  case 0xe002:fceulib__ines.iNESIRQa=V&2;if(!fceulib__ines.iNESIRQa) fceulib__ines.iNESIRQCount=0;X.IRQEnd(FCEU_IQEXT);break;
 }
}

static void Mapper42IRQ(int a) {
  if (fceulib__ines.iNESIRQa) {
    fceulib__ines.iNESIRQCount+=a;
    if (fceulib__ines.iNESIRQCount>=32768) fceulib__ines.iNESIRQCount-=32768;
    if (fceulib__ines.iNESIRQCount>=24576)
      X.IRQBegin(FCEU_IQEXT);
    else
      X.IRQEnd(FCEU_IQEXT);
  }
}

static void Mapper42_StateRestore(int version) {
  ROM_BANK8(0x6000,mapbyte1[0]&0xF);
}


void Mapper42_init(void) {
  ROM_BANK8(0x6000,0);
  ROM_BANK32(~0);
  fceulib__fceu.SetWriteHandler(0x6000,0xffff,Mapper42_write);
  fceulib__fceu.SetReadHandler(0x6000,0x7fff,Cart::CartBR);
  fceulib__ines.MapStateRestore=Mapper42_StateRestore;
  X.MapIRQHook=Mapper42IRQ;
}

