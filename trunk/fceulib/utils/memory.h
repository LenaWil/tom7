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

/*        Various macros for faster memory stuff
		(at least that's the idea) 
*/

// #define FCEU_dwmemset(d,c,n) {int _x; for(_x=n-4;_x>=0;_x-=4) *(uint32 *)&(d)[_x]=c;}
// Looks like memset but for 32-bit quantities, though n is still in bytes. -tom7
#define FCEU_dwmemset(d, c, n)			\
  do {						\
    int _nn = (n) >> 2;				\
    uint32 *_dest = (uint32 *)(d);		\
    for(int _x = _nn - 1; _x >= 0; _x--) {	\
      _dest[_x] = (c);				\
    }						\
  } while(0)


void *FCEU_malloc(uint32 size);
void *FCEU_gmalloc(uint32 size);
void FCEU_gfree(void *ptr);
