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

static uint8 latch;

static void Sync() {
  fceulib__.cart->setprg16(0x8000, latch);
  fceulib__.cart->setprg16(0xC000, 8);
}

static DECLFW(DREAMWrite) {
  latch = V & 7;
  Sync();
}

static void DREAMPower(FC *fc) {
  latch = 0;
  Sync();
  fceulib__.cart->setchr8(0);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x5020, 0x5020, DREAMWrite);
}

static void Restore(FC *fc, int version) {
  Sync();
}

void DreamTech01_Init(CartInfo *info) {
  fceulib__.fceu->GameStateRestore = Restore;
  info->Power = DREAMPower;
  fceulib__.state->AddExState(&latch, 1, 0, "LATC");
}
