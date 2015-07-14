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

static uint8 is48;
static uint8 regs[8], mirr;
static uint8 IRQa;
static int16 IRQCount, IRQLatch;

static SFORMAT StateRegs[] = {{regs, 8, "PREG"},      {&mirr, 1, "MIRR"},
                              {&IRQa, 1, "IRQA"},     {&IRQCount, 2, "IRQC"},
                              {&IRQLatch, 2, "IRQL"}, {0}};

static void Sync() {
  fceulib__.cart->setmirror(mirr);
  fceulib__.cart->setprg8(0x8000, regs[0]);
  fceulib__.cart->setprg8(0xA000, regs[1]);
  fceulib__.cart->setprg8(0xC000, ~1);
  fceulib__.cart->setprg8(0xE000, ~0);
  fceulib__.cart->setchr2(0x0000, regs[2]);
  fceulib__.cart->setchr2(0x0800, regs[3]);
  fceulib__.cart->setchr1(0x1000, regs[4]);
  fceulib__.cart->setchr1(0x1400, regs[5]);
  fceulib__.cart->setchr1(0x1800, regs[6]);
  fceulib__.cart->setchr1(0x1C00, regs[7]);
}

static DECLFW(M33Write) {
  A &= 0xF003;
  switch (A) {
    case 0x8000:
      regs[0] = V & 0x3F;
      if (!is48) mirr = ((V >> 6) & 1) ^ 1;
      Sync();
      break;
    case 0x8001:
      regs[1] = V & 0x3F;
      Sync();
      break;
    case 0x8002:
      regs[2] = V;
      Sync();
      break;
    case 0x8003:
      regs[3] = V;
      Sync();
      break;
    case 0xA000:
      regs[4] = V;
      Sync();
      break;
    case 0xA001:
      regs[5] = V;
      Sync();
      break;
    case 0xA002:
      regs[6] = V;
      Sync();
      break;
    case 0xA003:
      regs[7] = V;
      Sync();
      break;
  }
}

static DECLFW(M48Write) {
  switch (A & 0xF003) {
    case 0xC000: IRQLatch = V; break;
    case 0xC001: IRQCount = IRQLatch; break;
    case 0xC003:
      IRQa = 0;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xC002: IRQa = 1; break;
    case 0xE000:
      mirr = ((V >> 6) & 1) ^ 1;
      Sync();
      break;
  }
}

static void M33Power() {
  Sync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M33Write);
}

static void M48Power() {
  Sync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xBFFF, M33Write);
  fceulib__.fceu->SetWriteHandler(0xC000, 0xFFFF, M48Write);
}

static void M48IRQ() {
  if (IRQa) {
    IRQCount++;
    if (IRQCount == 0x100) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      IRQa = 0;
    }
  }
}

static void StateRestore(int version) {
  Sync();
}

void Mapper33_Init(CartInfo *info) {
  is48 = 0;
  info->Power = M33Power;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}

void Mapper48_Init(CartInfo *info) {
  is48 = 1;
  info->Power = M48Power;
  fceulib__.ppu->GameHBIRQHook = M48IRQ;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
