/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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

static uint8 FFEmode;

#define FVRAM_BANK8(A, V)                                             \
  {                                                                   \
    fceulib__.cart->VPage[0] = fceulib__.cart->VPage[1] =             \
        fceulib__.cart->VPage[2] = fceulib__.cart->VPage[3] =         \
            fceulib__.cart->VPage[4] = fceulib__.cart->VPage[5] =     \
                fceulib__.cart->VPage[6] = fceulib__.cart->VPage[7] = \
                    V ? &MapperExRAM[(V) << 13] - (A) :               \
                        &CHRRAM[(V) << 13] - (A);                     \
    fceulib__.ines->iNESCHRBankList[0] = ((V) << 3);                  \
    fceulib__.ines->iNESCHRBankList[1] = ((V) << 3) + 1;              \
    fceulib__.ines->iNESCHRBankList[2] = ((V) << 3) + 2;              \
    fceulib__.ines->iNESCHRBankList[3] = ((V) << 3) + 3;              \
    fceulib__.ines->iNESCHRBankList[4] = ((V) << 3) + 4;              \
    fceulib__.ines->iNESCHRBankList[5] = ((V) << 3) + 5;              \
    fceulib__.ines->iNESCHRBankList[6] = ((V) << 3) + 6;              \
    fceulib__.ines->iNESCHRBankList[7] = ((V) << 3) + 7;              \
    fceulib__.ppu->PPUCHRRAM = 0xFF;                                  \
  }

static void FFEIRQHook(FC *fc, int a) {
  if (fceulib__.ines->iNESIRQa) {
    fceulib__.ines->iNESIRQCount += a;
    if (fceulib__.ines->iNESIRQCount >= 0x10000) {
      fceulib__.X->IRQBegin(FCEU_IQEXT);
      fceulib__.ines->iNESIRQa = 0;
      fceulib__.ines->iNESIRQCount = 0;
    }
  }
}

DECLFW(Mapper6_write) {
  if (A < 0x8000) {
    switch (A) {
    case 0x42FF: fceulib__.ines->MIRROR_SET((V >> 4) & 1); break;
    case 0x42FE:
      fceulib__.ines->onemir((V >> 3) & 2);
      FFEmode = V & 0x80;
      break;
    case 0x4501:
      fceulib__.ines->iNESIRQa = 0;
      fceulib__.X->IRQEnd(FCEU_IQEXT);
      break;
    case 0x4502:
      fceulib__.ines->iNESIRQCount &= 0xFF00;
      fceulib__.ines->iNESIRQCount |= V;
      break;
    case 0x4503:
      fceulib__.ines->iNESIRQCount &= 0xFF;
      fceulib__.ines->iNESIRQCount |= V << 8;
      fceulib__.ines->iNESIRQa = 1;
      break;
    }
  } else {
    switch (FFEmode) {
    case 0x80: fceulib__.cart->setchr8(V); break;
    default: ROM_BANK16(fc, 0x8000, V >> 2); FVRAM_BANK8(0x0000, V & 3);
    }
  }
}

void Mapper6_StateRestore(int version) {
  for (int x = 0; x < 8; x++)
    if (fceulib__.ppu->PPUCHRRAM & (1 << x)) {
      if (fceulib__.ines->iNESCHRBankList[x] > 7) {
        fceulib__.cart->VPage[x] =
            &MapperExRAM[(fceulib__.ines->iNESCHRBankList[x] & 31) * 0x400] -
            (x * 0x400);
      } else {
        fceulib__.cart->VPage[x] =
            &CHRRAM[(fceulib__.ines->iNESCHRBankList[x] & 7) * 0x400] -
            (x * 0x400);
      }
    }
}

void Mapper6_init() {
  fceulib__.X->MapIRQHook = FFEIRQHook;
  ROM_BANK16(&fceulib__, 0xc000, 7);

  fceulib__.fceu->SetWriteHandler(0x4020, 0x5fff, Mapper6_write);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xffff, Mapper6_write);
  fceulib__.ines->MapStateRestore = Mapper6_StateRestore;
}
