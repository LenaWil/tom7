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

static uint8 *WRAM = NULL;
static constexpr uint32 WRAMSIZE = 8192;

// FIXME: 10/28 - now implemented in SDL as well.
// should we rename this to a FCEUI_* function?
unsigned int *GetKeyboard();

static unsigned int *TransformerKeys, oldkeys[256];
static int TransformerCycleCount, TransformerChar = 0;

static void TransformerIRQHook(int a) {
  TransformerCycleCount += a;
  if (TransformerCycleCount >= 1000) {
    uint32 i;
    TransformerCycleCount -= 1000;
    TransformerKeys = GetKeyboard();

    for (i = 0; i < 256; i++) {
      if (oldkeys[i] != TransformerKeys[i]) {
        if (oldkeys[i] == 0)
          TransformerChar = i;
        else
          TransformerChar = i | 0x80;
        fceulib__.X->IRQBegin(FCEU_IQEXT);
        memcpy((void *)&oldkeys[0], (void *)TransformerKeys, 256);
        break;
      }
    }
  }
}

static DECLFR(TransformerRead) {
  uint8 ret = 0;
  switch (A & 3) {
    case 0: ret = TransformerChar & 15; break;
    case 1: ret = (TransformerChar >> 4); break;
    case 2: break;
    case 4: break;
  }
  fceulib__.X->IRQEnd(FCEU_IQEXT);
  return ret;
}

static void TransformerPower(FC *Fc) {
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setprg16(0x8000, 0);
  fceulib__.cart->setprg16(0xC000, ~0);
  fceulib__.cart->setchr8(0);

  fceulib__.fceu->SetReadHandler(0x5000, 0x5004, TransformerRead);
  fceulib__.fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);

  fceulib__.X->MapIRQHook = TransformerIRQHook;
}

static void TransformerClose(FC *fc) {
  free(WRAM);
  WRAM = nullptr;
}

void Transformer_Init(CartInfo *info) {
  info->Power = TransformerPower;
  info->Close = TransformerClose;

  WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = WRAMSIZE;
  }
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
}
