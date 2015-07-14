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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "mapinc.h"

static uint8 preg[2], creg[8], mirr;

static uint8 *WRAM=NULL;
static uint32 WRAMSIZE;

static SFORMAT StateRegs[] =
{
	{ preg, 4, "PREG" },
	{ creg, 8, "CREG" },
	{ &mirr, 1, "MIRR" },
	{ 0 }
};

static void Sync(void) {
  uint16 swap = ((mirr & 2) << 13);
  fceulib__.cart->setmirror((mirr & 1) ^ 1);
  fceulib__.cart->setprg8r(0x10, 0x6000, 0);
  fceulib__.cart->setprg8(0x8000 ^ swap, preg[0]);
  fceulib__.cart->setprg8(0xA000, preg[1]);
  fceulib__.cart->setprg8(0xC000 ^ swap, ~1);
  fceulib__.cart->setprg8(0xE000, ~0);
  for (uint8 i = 0; i < 8; i++)
    fceulib__.cart->setchr1(i << 10, creg[i]);
}

static DECLFW(M32Write0) {
	preg[0] = V;
	Sync();
}

static DECLFW(M32Write1) {
	mirr = V;
	Sync();
}

static DECLFW(M32Write2) {
	preg[1] = V;
	Sync();
}

static DECLFW(M32Write3) {
	creg[A & 7] = V;
	Sync();
}

static void M32Power(void) {
	Sync();
	fceulib__.fceu->SetReadHandler(0x6000,0x7fff, Cart::CartBR);
	fceulib__.fceu->SetWriteHandler(0x6000,0x7fff, Cart::CartBW);
	fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
	fceulib__.fceu->SetWriteHandler(0x8000, 0x8FFF, M32Write0);
	fceulib__.fceu->SetWriteHandler(0x9000, 0x9FFF, M32Write1);
	fceulib__.fceu->SetWriteHandler(0xA000, 0xAFFF, M32Write2);
	fceulib__.fceu->SetWriteHandler(0xB000, 0xBFFF, M32Write3);
}

static void M32Close(void)
{
	if (WRAM)
		free(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	Sync();
}

void Mapper32_Init(CartInfo *info) {
  info->Power = M32Power;
  info->Close = M32Close;
  fceulib__.fceu->GameStateRestore = StateRestore;

  WRAMSIZE = 8192;
  WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
  fceulib__.cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  fceulib__.state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

  fceulib__.state->AddExState(&StateRegs, ~0, 0, 0);
}
