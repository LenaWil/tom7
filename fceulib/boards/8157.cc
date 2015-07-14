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
static uint8 invalid_data;
static SFORMAT StateRegs[] = {
    {&invalid_data, 1, "INVD"}, {&cmdreg, 2, "CREG"}, {0}};

static void Sync(void) {
  fceulib__.cart->setprg16r((cmdreg & 0x060) >> 5, 0x8000,
                            (cmdreg & 0x01C) >> 2);
  fceulib__.cart->setprg16r((cmdreg & 0x060) >> 5, 0xC000,
                            (cmdreg & 0x200) ? (~0) : 0);
  fceulib__.cart->setmirror(((cmdreg & 2) >> 1) ^ 1);
}

static DECLFR(UNL8157Read) {
  if (invalid_data && cmdreg & 0x100)
    return 0xFF;
  else
    return Cart::CartBR(DECLFR_FORWARD);
}

static DECLFW(UNL8157Write) {
  cmdreg = A;
  Sync();
}

static void UNL8157Power(void) {
  fceulib__.cart->setchr8(0);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, UNL8157Write);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, UNL8157Read);
  cmdreg = 0x200;
  invalid_data = 1;
  Sync();
}

static void UNL8157Reset(void) {
  cmdreg = 0;
  invalid_data ^= 1;
  Sync();
}

static void UNL8157Restore(int version) {
  Sync();
}

void UNL8157_Init(CartInfo *info) {
  info->Power = UNL8157Power;
  info->Reset = UNL8157Reset;
  fceulib__.fceu->GameStateRestore = UNL8157Restore;
  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
