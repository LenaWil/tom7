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

static DECLFW(Mapper42_write) {
  // FCEU_printf("%04x:%04x\n",A,V);
  switch (A & 0xe003) {
  case 0x8000: VROM_BANK8(fc, V); break;
  case 0xe000:
    mapbyte1[0] = V;
    ROM_BANK8(fc, 0x6000, V & 0xF);
    break;
  case 0xe001: fceulib__.ines->MIRROR_SET((V >> 3) & 1); break;
  case 0xe002:
    fceulib__.ines->iNESIRQa = V & 2;
    if (!fceulib__.ines->iNESIRQa) fceulib__.ines->iNESIRQCount = 0;
    fceulib__.X->IRQEnd(FCEU_IQEXT);
    break;
  }
}

static void Mapper42IRQ(FC *fc, int a) {
  if (fceulib__.ines->iNESIRQa) {
    fceulib__.ines->iNESIRQCount += a;
    if (fceulib__.ines->iNESIRQCount >= 32768)
      fceulib__.ines->iNESIRQCount -= 32768;
    if (fceulib__.ines->iNESIRQCount >= 24576)
      fceulib__.X->IRQBegin(FCEU_IQEXT);
    else
      fceulib__.X->IRQEnd(FCEU_IQEXT);
  }
}

static void Mapper42_StateRestore(int version) {
  ROM_BANK8(&fceulib__, 0x6000, mapbyte1[0] & 0xF);
}

void Mapper42_init() {
  ROM_BANK8(&fceulib__, 0x6000, 0);
  ROM_BANK32(&fceulib__, ~0);
  fceulib__.fceu->SetWriteHandler(0x6000, 0xffff, Mapper42_write);
  fceulib__.fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
  fceulib__.ines->MapStateRestore = Mapper42_StateRestore;
  fceulib__.X->MapIRQHook = Mapper42IRQ;
}
