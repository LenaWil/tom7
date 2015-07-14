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

static uint8 reg[4];
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] = {{reg, 4, "REGS"}, {0}};

static void Sync() {
  uint8 bank = (reg[2] & 3) << 3;
  fceulib__.cart->setmirror((reg[0] & 1) ^ 1);
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setchr8(0);
  if (reg[0] & 2) {
    fceulib__.cart->setprg16(0x8000, (reg[1] & 7) | bank);
    fceulib__.cart->setprg16(0xC000, ((~0) & 7) | bank);
  } else {
    fceulib__.cart->setprg16(0x8000, (reg[1] & 6) | bank);
    fceulib__.cart->setprg16(0xC000, (reg[1] & 6) | bank | 1);
  }
}

static DECLFW(M178Write) {
  reg[A & 3] = V;
  Sync();
}

static void M178Power() {
  reg[0] = 1;
  reg[1] = 0;
  reg[2] = 0;
  reg[3] = 0;
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4800, 0x4803, M178Write);
}

static void M178Close() {
  if (WRAM) free(WRAM);
  WRAM = NULL;
}

static void StateRestore(int version) {
  Sync();
}

void Mapper178_Init(CartInfo *info) {
  info->Power = M178Power;
  info->Close = M178Close;
  fceulib__.fceu->GameStateRestore = StateRestore;

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = WRAMSIZE;
  }
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
