/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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

static uint8 reg[2];

static uint8 *WRAM = nullptr;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] = {{reg, 2, "REG"}, {0}};

static void Sync() {
  fceulib__.cart->setchr8(0);
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setprg32(0x8000, reg[1] >> 1);
  fceulib__.cart->setmirror((reg[0] & 1) ^ 1);
}

static DECLFW(M179Write) {
  if (A == 0xa000) reg[0] = V;
  Sync();
}

static DECLFW(M179WriteLo) {
  if (A == 0x5ff1) reg[1] = V;
  Sync();
}

static void M179Power(FC *fc) {
  reg[0] = reg[1] = 0;
  Sync();
  fceulib__.fceu->SetWriteHandler(0x4020, 0x5fff, M179WriteLo);
  fceulib__.fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M179Write);
}

static void M179Close(FC *fc) {
  free(WRAM);
  WRAM = nullptr;
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper179_Init(CartInfo *info) {
  info->Power = M179Power;
  info->Close = M179Close;
  fceulib__.fceu->GameStateRestore = StateRestore;

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = WRAMSIZE;
  }

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
