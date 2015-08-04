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

static uint8 latch;

static void DoNovel() {
  fceulib__.cart->setprg32(0x8000, latch & 3);
  fceulib__.cart->setchr8(latch & 7);
}

static DECLFW(NovelWrite) {
  latch = A & 0xFF;
  DoNovel();
}

static void NovelReset(FC *fc) {
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, NovelWrite);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.cart->setprg32(0x8000, 0);
  fceulib__.cart->setchr8(0);
}

static void NovelRestore(FC *fc, int version) {
  DoNovel();
}

void Novel_Init(CartInfo *info) {
  fceulib__.state->AddExState(&latch, 1, 0, "L100");
  info->Power = NovelReset;
  fceulib__.fceu->GameStateRestore = NovelRestore;
}
