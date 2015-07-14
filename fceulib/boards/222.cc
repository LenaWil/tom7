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
 * (VRC4 mapper)
 */

#include "mapinc.h"

static uint8 IRQCount;
static uint8 IRQa;
static uint8 prg_reg[2];
static uint8 chr_reg[8];
static uint8 mirr;

static SFORMAT StateRegs[] = {{&IRQCount, 1, "IRQC"}, {&IRQa, 1, "IRQA"},
                              {prg_reg, 2, "PRG"},    {chr_reg, 8, "CHR"},
                              {&mirr, 1, "MIRR"},     {0}};

static void M222IRQ() {
  if (IRQa) {
    IRQCount++;
    if (IRQCount >= 238) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      //      IRQa=0;
    }
  }
}

static void Sync() {
  fceulib__.cart->setprg8(0x8000, prg_reg[0]);
  fceulib__.cart->setprg8(0xA000, prg_reg[1]);
  for (int i = 0; i < 8; i++) fceulib__.cart->setchr1(i << 10, chr_reg[i]);
  fceulib__.cart->setmirror(mirr ^ 1);
}

static DECLFW(M222Write) {
  switch (A & 0xF003) {
    case 0x8000: prg_reg[0] = V; break;
    case 0x9000: mirr = V & 1; break;
    case 0xA000: prg_reg[1] = V; break;
    case 0xB000: chr_reg[0] = V; break;
    case 0xB002: chr_reg[1] = V; break;
    case 0xC000: chr_reg[2] = V; break;
    case 0xC002: chr_reg[3] = V; break;
    case 0xD000: chr_reg[4] = V; break;
    case 0xD002: chr_reg[5] = V; break;
    case 0xE000: chr_reg[6] = V; break;
    case 0xE002:
      chr_reg[7] = V;
      break;
    //    case 0xF000: FCEU_printf("%04x:%02x %d\n",A,V,scanline); IRQa=V;
    //    if(!V)IRQPre=0; fceulib__.X->IRQEnd(FCEU_IQEXT); break;
    //    case 0xF001: FCEU_printf("%04x:%02x %d\n",A,V,scanline); IRQCount=V;
    //    break;
    //    case 0xF002: FCEU_printf("%04x:%02x %d\n",A,V,scanline); break;
    //    case 0xD001: IRQa=V; fceulib__.X->IRQEnd(FCEU_IQEXT);
    //    FCEU_printf("%04x:%02x %d\n",A,V,scanline); break;
    //    case 0xC001: IRQPre=16; FCEU_printf("%04x:%02x %d\n",A,V,scanline);
    //    break;
    case 0xF000:
      IRQa = IRQCount = V;
      if (fceulib__.ppu->scanline < 240)
        IRQCount -= 8;
      else
        IRQCount += 4;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
  }
  Sync();
}

static void M222Power() {
  fceulib__.cart->setprg16(0xC000, ~0);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M222Write);
}

static void StateRestore(int version) {
  Sync();
}

void Mapper222_Init(CartInfo *info) {
  info->Power = M222Power;
  fceulib__.ppu->GameHBIRQHook = M222IRQ;
  fceulib__.fceu->GameStateRestore = StateRestore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
