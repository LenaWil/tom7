/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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

static uint8 regs[9], ctrl;
static uint8 *WRAM82 = NULL;
static uint32 WRAM82SIZE;

static SFORMAT StateRegs[] = {{regs, 9, "REGS"}, {&ctrl, 1, "CTRL"}, {0}};

static void Sync() {
  uint32 swap = ((ctrl & 2) << 11);
  fceulib__.cart->setchr2(0x0000 ^ swap, regs[0] >> 1);
  fceulib__.cart->setchr2(0x0800 ^ swap, regs[1] >> 1);
  fceulib__.cart->setchr1(0x1000 ^ swap, regs[2]);
  fceulib__.cart->setchr1(0x1400 ^ swap, regs[3]);
  fceulib__.cart->setchr1(0x1800 ^ swap, regs[4]);
  fceulib__.cart->setchr1(0x1c00 ^ swap, regs[5]);
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setprg8(0x8000, regs[6]);
  fceulib__.cart->setprg8(0xA000, regs[7]);
  fceulib__.cart->setprg8(0xC000, regs[8]);
  fceulib__.cart->setprg8(0xE000, ~0);
  fceulib__.cart->setmirror(ctrl & 1);
}

static DECLFW(M82Write) {
  if (A <= 0x7ef5)
    regs[A & 7] = V;
  else
    switch (A) {
      case 0x7ef6: ctrl = V & 3; break;
      case 0x7efa: regs[6] = V >> 2; break;
      case 0x7efb: regs[7] = V >> 2; break;
      case 0x7efc: regs[8] = V >> 2; break;
    }
  Sync();
}

static void M82Power(FC *fc) {
  Sync();
  fceulib__.fceu->SetReadHandler(0x6000, 0xffff, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
  fceulib__.fceu->SetWriteHandler(
      0x7ef0, 0x7efc, M82Write);  // external WRAM82 might end at $73FF
}

static void M82Close(FC *fc) {
  free(WRAM82);
  WRAM82 = NULL;
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void Mapper82_Init(CartInfo *info) {
  info->Power = M82Power;
  // Note: This used to set Power a second time, which has got to be
  // a mistake. Changed to Close. -tom7
  info->Close = M82Close;

  WRAM82SIZE = 8192;
  WRAM82 = (uint8 *)FCEU_gmalloc(WRAM82SIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM82, WRAM82SIZE, 1);
  fceulib__.state->AddExState(WRAM82, WRAM82SIZE, 0, "WR82");
  if (info->battery) {
    info->SaveGame[0] = WRAM82;
    info->SaveGameLen[0] = WRAM82SIZE;
  }
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
