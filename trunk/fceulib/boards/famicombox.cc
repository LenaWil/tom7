/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static uint8 regs[8];
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] = {{regs, 8, "REGS"}, {0}};

static void Sync() {
  fceulib__.cart->setprg2r(0x10, 0x0800, 0);
  fceulib__.cart->setprg2r(0x10, 0x1000, 1);
  fceulib__.cart->setprg2r(0x10, 0x1800, 2);
  fceulib__.cart->setprg8r(0x10, 0x6000, 1);
  fceulib__.cart->setprg16(0x8000, 0);
  fceulib__.cart->setprg16(0xC000, ~0);
  fceulib__.cart->setchr8(0);
}

// static DECLFW(SSSNROMWrite)
//{
//  CartBW(A,V);
//}

static DECLFW(SSSNROMWrite) {
  // FCEU_printf("write %04x %02x\n",A,V);
  // regs[A&7] = V;
}

static DECLFR(SSSNROMRead) {
  // FCEU_printf("read %04x\n",A);
  switch (A & 7) {
    case 0: return regs[0] = 0xff;  // clear all exceptions
    case 2: return 0xc0;  // DIP selftest + freeplay
    case 3:
      return 0x00;  // 0, 1 - attract
    // 2
    // 4    - menu
    // 8    - self check and game casette check
    // 10   - lock?
    // 20   - game title & count display
    case 7: return 0x22;  // TV type, key not turned, relay B
    default: return 0;
  }
}

static void SSSNROMPower() {
  regs[0] = regs[1] = regs[2] = regs[3] = regs[4] = regs[5] = regs[6] = 0;
  regs[7] = 0xff;
  Sync();
  memset(WRAM, 0x00, WRAMSIZE);
  //  fceulib__.fceu->SetWriteHandler(0x0000,0x1FFF,SSSNROMRamWrite);
  fceulib__.fceu->SetReadHandler(0x0800, 0x1FFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x0800, 0x1FFF, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x5000, 0x5FFF, SSSNROMRead);
  fceulib__.fceu->SetWriteHandler(0x5000, 0x5FFF, SSSNROMWrite);
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
}

static void SSSNROMReset() {
  regs[1] = regs[2] = regs[3] = regs[4] = regs[5] = regs[6] = 0;
}

static void SSSNROMClose() {
  free(WRAM);
  WRAM = nullptr;
}

static void SSSNROMIRQHook() {
  //  fceulib__.X->IRQBegin(FCEU_IQEXT);
}

static void StateRestore(int version) {
  Sync();
}

void SSSNROM_Init(CartInfo *info) {
  info->Reset = SSSNROMReset;
  info->Power = SSSNROMPower;
  info->Close = SSSNROMClose;
  fceulib__.ppu->GameHBIRQHook = SSSNROMIRQHook;
  fceulib__.fceu->GameStateRestore = StateRestore;

  WRAMSIZE = 16384;
  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);

  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
