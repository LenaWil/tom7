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
#include "mmc3.h"

static void SA9602BPW(uint32 A, uint8 V) {
  fceulib__.cart->setprg8r(EXPREGS[1], A, V & 0x3F);
  if (MMC3_cmd & 0x40)
    fceulib__.cart->setprg8r(0, 0x8000, ~(1));
  else
    fceulib__.cart->setprg8r(0, 0xc000, ~(1));
  fceulib__.cart->setprg8r(0, 0xe000, ~(0));
}

static DECLFW(SA9602BWrite) {
  switch (A & 0xe001) {
    case 0x8000: EXPREGS[0] = V; break;
    case 0x8001:
      if ((EXPREGS[0] & 7) < 6) {
        EXPREGS[1] = V >> 6;
        FixMMC3PRG(MMC3_cmd);
      }
      break;
  }
  MMC3_CMDWrite(DECLFW_FORWARD);
}

static void SA9602BPower(void) {
  EXPREGS[0] = EXPREGS[1] = 0;
  GenMMC3Power();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xBFFF, SA9602BWrite);
}

void SA9602B_Init(CartInfo *info) {
  GenMMC3_Init(info, 512, 0, 0, 0);
  pwrap = SA9602BPW;
  mmc3opts |= 2;
  info->SaveGame[0] = fceulib__.unif->UNIFchrrama;
  info->SaveGameLen[0] = 32 * 1024;
  info->Power = SA9602BPower;
  fceulib__.state->AddExState(EXPREGS, 2, 0, "EXPR");
}
