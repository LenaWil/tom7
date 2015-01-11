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

#ifndef __STATE_H
#define __STATE_H

#include <vector>
#include "types.h"

#if 0
enum ENUM_SSLOADPARAMS {
  // PERF no need for backups!
  SSLOADPARAM_NOBACKUP,
  SSLOADPARAM_BACKUP,
};
#endif

struct SFORMAT {
  // a void* to the data or a void** to the data
  void *v;

  // size, plus flags
  uint32 s;
  
  // a string description of the element
  char *desc;
};

// Tom 7's simplified versions. These should only be used for in-memory saves!
bool FCEUSS_SaveRAW(std::vector<uint8> *out);
bool FCEUSS_LoadRAW(std::vector<uint8> *in);

// I think these add additional locations to the set of saved memories.
void ResetExState(void (*PreSave)(),void (*PostSave)());
void AddExState(void *v, uint32 s, int type, char *desc);

// indicates that the value is a multibyte integer that needs to be
// put in the correct byte order
#define FCEUSTATE_RLSB            0x80000000
// void*v is actually a void** which will be indirected before reading
#define FCEUSTATE_INDIRECT            0x40000000
// all FCEUSTATE flags together so that we can mask them out and get
// the size
#define FCEUSTATE_FLAGS (FCEUSTATE_RLSB|FCEUSTATE_INDIRECT)

#endif
