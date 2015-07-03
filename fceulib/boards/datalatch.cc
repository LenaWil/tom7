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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "mapinc.h"
#include "../ines.h"

static uint8 latche, latcheinit, bus_conflict;
static uint16 addrreg0, addrreg1;
static uint8 *WRAM = NULL;
static uint32 WRAMSIZE;
static void (*WSync)(void);

static DECLFW(LatchWrite) {
//	FCEU_printf("bs %04x %02x\n",A,V);
	if (bus_conflict)
	  latche = V & Cart::CartBR(A);
	else
		latche = V;
	WSync();
}

static void LatchPower(void) {
  latche = latcheinit;
  WSync();
  if (WRAM) {
    fceulib__fceu.SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fceulib__fceu.SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  } else {
    fceulib__fceu.SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }
  fceulib__fceu.SetWriteHandler(addrreg0, addrreg1, LatchWrite);
}

static void LatchClose(void) {
	if (WRAM)
		free(WRAM);
	WRAM = NULL;
}

static void StateRestore(int version) {
	WSync();
}

static void Latch_Init(CartInfo *info, void (*proc)(void), uint8 init, uint16 adr0, uint16 adr1, uint8 wram, uint8 busc) {
  bus_conflict = busc;
  latcheinit = init;
  addrreg0 = adr0;
  addrreg1 = adr1;
  WSync = proc;
  info->Power = LatchPower;
  info->Close = LatchClose;
  fceulib__fceu.GameStateRestore = StateRestore;
  if (wram) {
    WRAMSIZE = 8192;
    WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
    fceulib__cart.SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }
    AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  }
  AddExState(&latche, 1, 0, "LATC");
  AddExState(&bus_conflict, 1, 0, "BUSC");
}

//------------------ Map 0 ---------------------------

#ifdef DEBUG_MAPPER
static DECLFW(NROMWrite) {
	FCEU_printf("bs %04x %02x\n", A, V);
	CartBW(A, V);
}
#endif

static void NROMPower(void) {
  fceulib__cart.setprg8r(0x10, 0x6000, 0); // Famili BASIC (v3.0) need it (uses only 4KB), FP-BASIC uses 8KB
  fceulib__cart.setprg16(0x8000, 0);
  fceulib__cart.setprg16(0xC000, ~0);
  fceulib__cart.setchr8(0);

  fceulib__fceu.SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
  fceulib__fceu.SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
  fceulib__fceu.SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);

#ifdef DEBUG_MAPPER
  fceulib__fceu.SetWriteHandler(0x4020, 0xFFFF, NROMWrite);
#endif
}

void NROM_Init(CartInfo *info) {
  info->Power = NROMPower;
  info->Close = LatchClose;

  WRAMSIZE = 8192;
  WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
  fceulib__cart.SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
  if (info->battery) {
    info->SaveGame[0] = WRAM;
    info->SaveGameLen[0] = WRAMSIZE;
  }
  AddExState(WRAM, WRAMSIZE, 0, "WRAM");
}

//------------------ Map 2 ---------------------------

static void UNROMSync(void) {
  static uint32 mirror_in_use = 0;
  if (fceulib__cart.PRGsize[0] <= 128 * 1024) {
    fceulib__cart.setprg16(0x8000, latche & 0x7);
    if (latche & 8) mirror_in_use = 1;
    if (mirror_in_use) {
      // Higway Star Hacked mapper
      fceulib__cart.setmirror(((latche >> 3) & 1) ^ 1);
    }
  } else {
    fceulib__cart.setprg16(0x8000, latche & 0xf);
  }
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8(0);
}

void UNROM_Init(CartInfo *info) {
  Latch_Init(info, UNROMSync, 0, 0x8000, 0xFFFF, 0, 1);
}

//------------------ Map 3 ---------------------------

static void CNROMSync(void) {
  fceulib__cart.setchr8(latche);
  fceulib__cart.setprg32(0x8000, 0);
  fceulib__cart.setprg8r(0x10, 0x6000, 0); // Hayauchy IGO uses 2Kb or RAM
}

void CNROM_Init(CartInfo *info) {
  Latch_Init(info, CNROMSync, 0, 0x8000, 0xFFFF, 1, 1);
}

//------------------ Map 7 ---------------------------

static void ANROMSync() {
  fceulib__cart.setprg32(0x8000, latche & 0xf);
  fceulib__cart.setmirror(MI_0 + ((latche >> 4) & 1));
  fceulib__cart.setchr8(0);
}

void ANROM_Init(CartInfo *info) {
  Latch_Init(info, ANROMSync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 8 ---------------------------

static void M8Sync() {
  fceulib__cart.setprg16(0x8000, latche >> 3);
  fceulib__cart.setprg16(0xc000, 1);
  fceulib__cart.setchr8(latche & 3);
}

void Mapper8_Init(CartInfo *info) {
  Latch_Init(info, M8Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 11 ---------------------------

static void M11Sync(void) {
  fceulib__cart.setprg32(0x8000, latche & 0xf);
  fceulib__cart.setchr8(latche >> 4);
}

void Mapper11_Init(CartInfo *info) {
  Latch_Init(info, M11Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

void Mapper144_Init(CartInfo *info) {
  Latch_Init(info, M11Sync, 0, 0x8001, 0xFFFF, 0, 0);
}

//------------------ Map 13 ---------------------------

static void CPROMSync(void) {
  fceulib__cart.setchr4(0x0000, 0);
  fceulib__cart.setchr4(0x1000, latche & 3);
  fceulib__cart.setprg32(0x8000, 0);
}

void CPROM_Init(CartInfo *info) {
  Latch_Init(info, CPROMSync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 36 ---------------------------

static void M36Sync(void) {
  fceulib__cart.setprg32(0x8000, latche >> 4);
  fceulib__cart.setchr8((latche) & 0xF);
}

void Mapper36_Init(CartInfo *info) {
  Latch_Init(info, M36Sync, 0, 0x8400, 0xfffe, 0, 0);
}

//------------------ Map 38 ---------------------------

static void M38Sync(void) {
  fceulib__cart.setprg32(0x8000, latche & 3);
  fceulib__cart.setchr8(latche >> 2);
}

void Mapper38_Init(CartInfo *info) {
  Latch_Init(info, M38Sync, 0, 0x7000, 0x7FFF, 0, 0);
}

//------------------ Map 66 ---------------------------

static void MHROMSync(void) {
  fceulib__cart.setprg32(0x8000, latche >> 4);
  fceulib__cart.setchr8(latche & 0xf);
}

void MHROM_Init(CartInfo *info) {
  Latch_Init(info, MHROMSync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 70 ---------------------------

static void M70Sync() {
  fceulib__cart.setprg16(0x8000, latche >> 4);
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8(latche & 0xf);
}

void Mapper70_Init(CartInfo *info) {
  Latch_Init(info, M70Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 78 ---------------------------
/* Should be two separate emulation functions for this "mapper".  Sigh.  URGE TO KILL RISING. */
static void M78Sync() {
  fceulib__cart.setprg16(0x8000, (latche & 7));
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8(latche >> 4);
  fceulib__cart.setmirror(MI_0 + ((latche >> 3) & 1));
}

void Mapper78_Init(CartInfo *info) {
  Latch_Init(info, M78Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 86 ---------------------------

static void M86Sync(void) {
  fceulib__cart.setprg32(0x8000, (latche >> 4) & 3);
  fceulib__cart.setchr8((latche & 3) | ((latche >> 4) & 4));
}

void Mapper86_Init(CartInfo *info) {
  Latch_Init(info, M86Sync, ~0, 0x6000, 0x6FFF, 0, 0);
}

//------------------ Map 87 ---------------------------

static void M87Sync(void) {
  fceulib__cart.setprg32(0x8000, 0);
  fceulib__cart.setchr8(((latche >> 1) & 1) | ((latche << 1) & 2));
}

void Mapper87_Init(CartInfo *info) {
  Latch_Init(info, M87Sync, ~0, 0x6000, 0xFFFF, 0, 0);
}

//------------------ Map 89 ---------------------------

static void M89Sync(void) {
  fceulib__cart.setprg16(0x8000, (latche >> 4) & 7);
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8((latche & 7) | ((latche >> 4) & 8));
  fceulib__cart.setmirror(MI_0 + ((latche >> 3) & 1));
}

void Mapper89_Init(CartInfo *info) {
  Latch_Init(info, M89Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 93 ---------------------------

static void SSUNROMSync(void) {
  fceulib__cart.setprg16(0x8000, latche >> 4);
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8(0);
}

void SUNSOFT_UNROM_Init(CartInfo *info) {
  Latch_Init(info, SSUNROMSync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 94 ---------------------------

static void M94Sync(void) {
  fceulib__cart.setprg16(0x8000, latche >> 2);
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8(0);
}

void Mapper94_Init(CartInfo *info) {
  Latch_Init(info, M94Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 97 ---------------------------

static void M97Sync(void) {
  fceulib__cart.setchr8(0);
  fceulib__cart.setprg16(0x8000, ~0);
  fceulib__cart.setprg16(0xc000, latche & 15);
  switch (latche >> 6) {
  case 0: break;
  case 1: fceulib__cart.setmirror(MI_H); break;
  case 2: fceulib__cart.setmirror(MI_V); break;
  case 3: break;
  }
  fceulib__cart.setchr8(((latche >> 1) & 1) | ((latche << 1) & 2));
}

void Mapper97_Init(CartInfo *info) {
  Latch_Init(info, M97Sync, ~0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 101 ---------------------------

static void M101Sync(void) {
  fceulib__cart.setprg32(0x8000, 0);
  fceulib__cart.setchr8(latche);
}

void Mapper101_Init(CartInfo *info) {
  Latch_Init(info, M101Sync, ~0, 0x6000, 0x7FFF, 0, 0);
}

//------------------ Map 107 ---------------------------

static void M107Sync(void) {
  fceulib__cart.setprg32(0x8000, (latche >> 1) & 3);
  fceulib__cart.setchr8(latche & 7);
}

void Mapper107_Init(CartInfo *info) {
  Latch_Init(info, M107Sync, ~0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 113 ---------------------------

static void M113Sync(void) {
  fceulib__cart.setprg32(0x8000, (latche >> 3) & 7);
  fceulib__cart.setchr8(((latche >> 3) & 8) | (latche & 7));
  //	fceulib__cart.setmirror(latche>>7); // only for HES 6in1
}

void Mapper113_Init(CartInfo *info) {
  Latch_Init(info, M113Sync, 0, 0x4100, 0x7FFF, 0, 0);
}

//------------------ Map 140 ---------------------------

void Mapper140_Init(CartInfo *info) {
  Latch_Init(info, MHROMSync, 0, 0x6000, 0x7FFF, 0, 0);
}

//------------------ Map 152 ---------------------------

static void M152Sync() {
  fceulib__cart.setprg16(0x8000, (latche >> 4) & 7);
  fceulib__cart.setprg16(0xc000, ~0);
  fceulib__cart.setchr8(latche & 0xf);
  fceulib__cart.setmirror(MI_0 + ((latche >> 7) & 1));         /* Saint Seiya...hmm. */
}

void Mapper152_Init(CartInfo *info) {
  Latch_Init(info, M152Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 180 ---------------------------

static void M180Sync(void) {
  fceulib__cart.setprg16(0x8000, 0);
  fceulib__cart.setprg16(0xc000, latche);
  fceulib__cart.setchr8(0);
}

void Mapper180_Init(CartInfo *info) {
  Latch_Init(info, M180Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 184 ---------------------------

static void M184Sync(void) {
  fceulib__cart.setchr4(0x0000, latche);
  fceulib__cart.setchr4(0x1000, latche >> 4);
  fceulib__cart.setprg32(0x8000, 0);
}

void Mapper184_Init(CartInfo *info) {
  Latch_Init(info, M184Sync, 0, 0x6000, 0x7FFF, 0, 0);
}

//------------------ Map 203 ---------------------------

static void M203Sync(void) {
  fceulib__cart.setprg16(0x8000, (latche >> 2) & 3);
  fceulib__cart.setprg16(0xC000, (latche >> 2) & 3);
  fceulib__cart.setchr8(latche & 3);
}

void Mapper203_Init(CartInfo *info) {
  Latch_Init(info, M203Sync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ Map 240 ---------------------------

static void M240Sync(void) {
  fceulib__cart.setprg8r(0x10, 0x6000, 0);
  fceulib__cart.setprg32(0x8000, latche >> 4);
  fceulib__cart.setchr8(latche & 0xf);
}

void Mapper240_Init(CartInfo *info) {
  Latch_Init(info, M240Sync, 0, 0x4020, 0x5FFF, 1, 0);
}

//------------------ Map 241 ---------------------------
// Mapper 7 mostly, but with SRAM or maybe prot circuit
// figure out, which games do need 5xxx area reading

static void M241Sync(void) {
  fceulib__cart.setchr8(0);
  fceulib__cart.setprg8r(0x10, 0x6000, 0);
  fceulib__cart.setprg32(0x8000, latche);
}

void Mapper241_Init(CartInfo *info) {
  Latch_Init(info, M241Sync, 0, 0x8000, 0xFFFF, 1, 0);
}

//------------------ A65AS ---------------------------

// actually, there is two cart in one... First have extra mirroring
// mode (one screen) and 32K bankswitching, second one have only
// 16 bankswitching mode and normal mirroring... But there is no any
// correlations between modes and they can be used in one mapper code.

static void BMCA65ASSync(void) {
  if (latche & 0x40) {
    fceulib__cart.setprg32(0x8000, (latche >> 1) & 0x0F);
  } else {
    fceulib__cart.setprg16(0x8000, ((latche & 0x30) >> 1) | (latche & 7));
    fceulib__cart.setprg16(0xC000, ((latche & 0x30) >> 1) | 7);
  }
  fceulib__cart.setchr8(0);
  if (latche & 0x80)
    fceulib__cart.setmirror(MI_0 + (((latche >> 5) & 1)));
  else
    fceulib__cart.setmirror(((latche >> 3) & 1) ^ 1);
}

void BMCA65AS_Init(CartInfo *info) {
  Latch_Init(info, BMCA65ASSync, 0, 0x8000, 0xFFFF, 0, 0);
}

//------------------ BMC-11160 ---------------------------
// Simple BMC discrete mapper by TXC

static void BMC11160Sync(void) {
  uint32 bank = (latche >> 4) & 7;
  fceulib__cart.setprg32(0x8000, bank);
  fceulib__cart.setchr8((bank << 2) | (latche & 3));
  fceulib__cart.setmirror((latche >> 7) & 1);
}

void BMC11160_Init(CartInfo *info) {
  Latch_Init(info, BMC11160Sync, 0, 0x8000, 0xFFFF, 0, 0);
}