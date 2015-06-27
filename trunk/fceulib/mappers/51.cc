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

#define mode mapbyte1[0]
#define page mapbyte1[1]

static uint32 Get8K(uint32 A)
{
 uint32 bank;

 bank=(page<<2)|((A>>13)&1);

 if(A&0x4000 && !(mode&1)) bank|=0xC;
 if(!(A&0x8000)) bank|=0x20;
 if(mode==2) bank|=2;
 else bank|=(A>>13)&2;
 return(bank);
}

static void Synco(void)
{
 uint32 x;
 if(mapbyte1[0]<=2)
  fceulib__ines.MIRROR_SET2(1);
 else
  fceulib__ines.MIRROR_SET2(0);
 for(x=0x6000;x<0x10000;x+=8192)
  ROM_BANK8(x,Get8K(x));
}

static DECLFW(Write)
{
 if(A&0x8000) mapbyte1[1]=V&0xF;
 else mapbyte1[0]=(mapbyte1[0]&2)|((V>>1)&1);

 if(A&0x4000) mapbyte1[0]=(mapbyte1[0]&1)|((V>>3)&2);
 Synco();
}

void Mapper51_init(void) {
 fceulib__fceu.SetWriteHandler(0x6000,0xFFFF,Write);
 fceulib__fceu.SetReadHandler(0x6000,0xFFFF,Cart::CartBR);
 mapbyte1[0]=1;
 mapbyte1[1]=0;
 Synco();
}
