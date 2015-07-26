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
 */

#include "mapinc.h"
#include "mmc3.h"

static uint8 *CHRRAM = NULL;  // there is no more extern CHRRAM in mmc3.h
// I need chrram here and local   static == local
static int masko8[8] = {63, 31, 15, 1, 3, 0, 0, 0};

static void Super24PW(uint32 A, uint8 V) {
  uint32 NV = V & masko8[EXPREGS[0] & 7];
  NV |= (EXPREGS[1] << 1);
  fceulib__.cart->setprg8r((NV >> 6) & 0xF, A, NV);
}

static void Super24CW(uint32 A, uint8 V) {
  if (EXPREGS[0] & 0x20) {
    fceulib__.cart->setchr1r(0x10, A, V);
  } else {
    uint32 NV = V | (EXPREGS[2] << 3);
    fceulib__.cart->setchr1r((NV >> 9) & 0xF, A, NV);
  }
}

static DECLFW(Super24Write) {
  switch (A) {
    case 0x5FF0:
      EXPREGS[0] = V;
      FixMMC3PRG(MMC3_cmd);
      FixMMC3CHR(MMC3_cmd);
      break;
    case 0x5FF1:
      EXPREGS[1] = V;
      FixMMC3PRG(MMC3_cmd);
      break;
    case 0x5FF2:
      EXPREGS[2] = V;
      FixMMC3CHR(MMC3_cmd);
      break;
  }
}

static void Super24Power(FC *fc) {
  EXPREGS[0] = 0x24;
  EXPREGS[1] = 159;
  EXPREGS[2] = 0;
  GenMMC3Power(fc);
  fceulib__.fceu->SetWriteHandler(0x5000, 0x7FFF, Super24Write);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
}

static void Super24Reset(FC *fc) {
  EXPREGS[0] = 0x24;
  EXPREGS[1] = 159;
  EXPREGS[2] = 0;
  MMC3RegReset(fc);
}

static void Super24Close(FC *fc) {
  free(CHRRAM);
  CHRRAM = nullptr;
}

void Super24_Init(CartInfo *info) {
  GenMMC3_Init(info, 128, 256, 0, 0);
  info->Power = Super24Power;
  info->Reset = Super24Reset;
  info->Close = Super24Close;
  cwrap = Super24CW;
  pwrap = Super24PW;
  CHRRAM = (uint8 *)FCEU_gmalloc(8192);
  fceulib__.cart->SetupCartCHRMapping(0x10, CHRRAM, 8192, 1);
  fceulib__.state->AddExState(CHRRAM, 8192, 0, "CHRR");
  fceulib__.state->AddExState(EXPREGS, 3, 0, "BIG2");
}