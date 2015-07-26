/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2011 CaH4e3
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
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

static uint8 reg[8], cmd;
static uint8 *WRAM = nullptr;
static uint32 WRAMSIZE;

static void (*WSync)();

static SFORMAT StateRegs[] = {{&cmd, 1, "CMD"}, {reg, 8, "REGS"}, {0}};

static void SyncKS7037() {
  fceulib__.cart->setprg4r(0x10, 0x6000, 0);
  fceulib__.cart->setprg4(0x7000, 15);
  fceulib__.cart->setprg8(0x8000, reg[6]);
  fceulib__.cart->setprg4(0xA000, ~3);
  fceulib__.cart->setprg4r(0x10, 0xB000, 1);
  fceulib__.cart->setprg8(0xC000, reg[7]);
  fceulib__.cart->setprg8(0xE000, ~0);
  fceulib__.cart->setchr8(0);
  fceulib__.cart->setmirrorw(reg[2] & 1, reg[4] & 1, reg[3] & 1, reg[5] & 1);
}

static void SyncLH10() {
  fceulib__.cart->setprg8(0x6000, ~1);
  fceulib__.cart->setprg8(0x8000, reg[6]);
  fceulib__.cart->setprg8(0xA000, reg[7]);
  fceulib__.cart->setprg8r(0x10, 0xC000, 0);
  fceulib__.cart->setprg8(0xE000, ~0);
  fceulib__.cart->setchr8(0);
  fceulib__.cart->setmirror(0);
}

static DECLFW(UNLKS7037Write) {
  switch (A & 0xE001) {
    case 0x8000: cmd = V & 7; break;
    case 0x8001:
      reg[cmd] = V;
      WSync();
      break;
  }
}

static void UNLKS7037Power(FC *fc) {
  reg[0] = reg[1] = reg[2] = reg[3] = reg[4] = reg[5] = reg[6] = reg[7] = 0;
  WSync();
  fceulib__.fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetWriteHandler(0x8000, 0x9FFF, UNLKS7037Write);
  fceulib__.fceu->SetWriteHandler(0xA000, 0xBFFF, Cart::CartBW);
  fceulib__.fceu->SetWriteHandler(0xC000, 0xFFFF, UNLKS7037Write);
}

static void LH10Power(FC *fc) {
  reg[0] = reg[1] = reg[2] = reg[3] = reg[4] = reg[5] = reg[6] = reg[7] = 0;
  WSync();
  fceulib__.fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xBFFF, UNLKS7037Write);
  fceulib__.fceu->SetWriteHandler(0xC000, 0xDFFF, Cart::CartBW);
  fceulib__.fceu->SetWriteHandler(0xE000, 0xFFFF, UNLKS7037Write);
}

static void Close(FC *fc) {
  free(WRAM);
  WRAM = nullptr;
}

static void StateRestore(FC *fc, int version) {
  WSync();
}

void UNLKS7037_Init(CartInfo *info) {
  info->Power = UNLKS7037Power;
  info->Close = Close;

  WSync = SyncKS7037;

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}

void LH10_Init(CartInfo *info) {
  info->Power = LH10Power;
  info->Close = Close;

  WSync = SyncLH10;

  WRAMSIZE = 8192;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
