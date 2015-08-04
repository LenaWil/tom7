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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include "mapinc.h"

static uint8 mode;
static uint8 DRegs[4];

static vector<SFORMAT> StateRegs = {{DRegs, 4, "DREG"}};

static void Sync() {
  int base, bank;
  base = ((DRegs[0] ^ DRegs[1]) & 0x10) << 1;
  bank = (DRegs[2] ^ DRegs[3]) & 0x1f;

  if (DRegs[1] & 0x08) {
    bank &= 0xfe;
    if (mode == 0) {
      fceulib__.cart->setprg16(0x8000, base + bank + 1);
      fceulib__.cart->setprg16(0xC000, base + bank + 0);
    } else {
      fceulib__.cart->setprg16(0x8000, base + bank + 0);
      fceulib__.cart->setprg16(0xC000, base + bank + 1);
    }
  } else {
    if (DRegs[1] & 0x04) {
      fceulib__.cart->setprg16(0x8000, 0x1f);
      fceulib__.cart->setprg16(0xC000, base + bank);
    } else {
      fceulib__.cart->setprg16(0x8000, base + bank);
      if (mode == 0)
        fceulib__.cart->setprg16(0xC000, 0x20);
      else
        fceulib__.cart->setprg16(0xC000, 0x07);
    }
  }
}

static DECLFW(Mapper167_write) {
  DRegs[(A >> 13) & 0x03] = V;
  Sync();
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper166_init() {
  mode = 1;
  DRegs[0] = DRegs[1] = DRegs[2] = DRegs[3] = 0;
  Sync();
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, Mapper167_write);
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExVec(StateRegs);
}

void Mapper167_init() {
  mode = 0;
  DRegs[0] = DRegs[1] = DRegs[2] = DRegs[3] = 0;
  Sync();
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, Mapper167_write);
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExVec(StateRegs);
}
