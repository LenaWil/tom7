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

static uint16 cmdreg;
static SFORMAT StateRegs[] = {{&cmdreg, 2, "CREG"}, {0}};

static void Sync() {
  if (cmdreg & 0x400)
    fceulib__.cart->setmirror(MI_0);
  else
    fceulib__.cart->setmirror(((cmdreg >> 13) & 1) ^ 1);
  if (cmdreg & 0x800) {
    fceulib__.cart->setprg16(0x8000, ((cmdreg & 0x300) >> 3) |
                                         ((cmdreg & 0x1F) << 1) |
                                         ((cmdreg >> 12) & 1));
    fceulib__.cart->setprg16(0xC000, ((cmdreg & 0x300) >> 3) |
                                         ((cmdreg & 0x1F) << 1) |
                                         ((cmdreg >> 12) & 1));
  } else {
    fceulib__.cart->setprg32(0x8000, ((cmdreg & 0x300) >> 4) | (cmdreg & 0x1F));
  }
}

static DECLFW(M235Write) {
  cmdreg = A;
  Sync();
}

static void M235Power(FC *fc) {
  fceulib__.cart->setchr8(0);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, M235Write);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  cmdreg = 0;
  Sync();
}

static void M235Restore(FC *fc, int version) {
  Sync();
}

void Mapper235_Init(CartInfo *info) {
  info->Power = M235Power;
  fceulib__.fceu->GameStateRestore = M235Restore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
