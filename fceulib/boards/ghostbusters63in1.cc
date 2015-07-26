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
 * 63in1 ghostbusters
 */

#include "mapinc.h"

static uint8 reg[2], bank;
static constexpr uint8 banks[4] = {0, 0, 1, 2};
static uint8 *CHRROM = nullptr;
static uint32 CHRROMSIZE;

static SFORMAT StateRegs[] = {{reg, 2, "REGS"}, {&bank, 1, "BANK"}, {0}};

static void Sync() {
  if (reg[0] & 0x20) {
    fceulib__.cart->setprg16r(banks[bank], 0x8000, reg[0] & 0x1F);
    fceulib__.cart->setprg16r(banks[bank], 0xC000, reg[0] & 0x1F);
  } else {
    fceulib__.cart->setprg32r(banks[bank], 0x8000, (reg[0] >> 1) & 0x0F);
  }
  if (reg[1] & 2)
    fceulib__.cart->setchr8r(0x10, 0);
  else
    fceulib__.cart->setchr8(0);
  fceulib__.cart->setmirror((reg[0] & 0x40) >> 6);
}

static DECLFW(BMCGhostbusters63in1Write) {
  reg[A & 1] = V;
  bank = ((reg[0] & 0x80) >> 7) | ((reg[1] & 1) << 1);
  //	FCEU_printf("reg[0]=%02x, reg[1]=%02x, bank=%02x\n",reg[0],reg[1],bank);
  Sync();
}

static DECLFR(BMCGhostbusters63in1Read) {
  if (bank == 1)
    return fceulib__.X->DB;
  else
    return Cart::CartBR(DECLFR_FORWARD);
}

static void BMCGhostbusters63in1Power(FC *fc) {
  reg[0] = reg[1] = 0;
  Sync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, BMCGhostbusters63in1Read);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, BMCGhostbusters63in1Write);
}

static void BMCGhostbusters63in1Reset(FC *fc) {
  reg[0] = reg[1] = 0;
}

static void StateRestore(FC *fc, int version) {
  Sync();
}

static void BMCGhostbusters63in1Close(FC *fc) {
  free(CHRROM);
  CHRROM = nullptr;
}

void BMCGhostbusters63in1_Init(CartInfo *info) {
  info->Reset = BMCGhostbusters63in1Reset;
  info->Power = BMCGhostbusters63in1Power;
  info->Close = BMCGhostbusters63in1Close;

  CHRROMSIZE = 8192;  // dummy CHRROM, VRAM disable
  CHRROM = (uint8 *)FCEU_gmalloc(CHRROMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, CHRROM, CHRROMSIZE, 0);
  fceulib__.state->AddExState(CHRROM, CHRROMSIZE, 0, "CROM");

  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
