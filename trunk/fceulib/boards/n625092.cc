/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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
 * 700in1 and 400in1 carts
 */

#include "mapinc.h"

static uint16 cmd, bank;

static SFORMAT StateRegs[] = {{&cmd, 2, "CMD"}, {&bank, 2, "BANK"}, {0}};

static void Sync() {
  fceulib__.cart->setmirror((cmd & 1) ^ 1);
  fceulib__.cart->setchr8(0);
  if (cmd & 2) {
    if (cmd & 0x100) {
      fceulib__.cart->setprg16(0x8000, ((cmd & 0xfc) >> 2) | bank);
      fceulib__.cart->setprg16(0xC000, ((cmd & 0xfc) >> 2) | 7);
    } else {
      fceulib__.cart->setprg16(0x8000, ((cmd & 0xfc) >> 2) | (bank & 6));
      fceulib__.cart->setprg16(0xC000, ((cmd & 0xfc) >> 2) | ((bank & 6) | 1));
    }
  } else {
    fceulib__.cart->setprg16(0x8000, ((cmd & 0xfc) >> 2) | bank);
    fceulib__.cart->setprg16(0xC000, ((cmd & 0xfc) >> 2) | bank);
  }
}

static uint16 ass = 0;

static DECLFW(UNLN625092WriteCommand) {
  cmd = A;
  if (A == 0x80F8) {
    fceulib__.cart->setprg16(0x8000, ass);
    fceulib__.cart->setprg16(0xC000, ass);
  } else {
    Sync();
  }
}

static DECLFW(UNLN625092WriteBank) {
  bank = A & 7;
  Sync();
}

static void UNLN625092Power(FC *fc) {
  cmd = 0;
  bank = 0;
  Sync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xBFFF, UNLN625092WriteCommand);
  fceulib__.fceu->SetWriteHandler(0xC000, 0xFFFF, UNLN625092WriteBank);
}

static void UNLN625092Reset(FC *fc) {
  cmd = 0;
  bank = 0;
  ass++;
  FCEU_printf("%04x\n", ass);
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

void UNLN625092_Init(CartInfo *info) {
  info->Reset = UNLN625092Reset;
  info->Power = UNLN625092Power;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
