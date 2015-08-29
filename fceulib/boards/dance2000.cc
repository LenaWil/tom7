/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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

static constexpr int WRAMSIZE = 8192;

namespace {
struct UNLD2000 : public CartInterface {
  uint8 prg = 0, mirr = 0, prgmode = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setmirror(mirr);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setchr8(0);
    if (prgmode) {
      fc->cart->setprg32(0x8000, prg & 7);
    } else {
      fc->cart->setprg16(0x8000, prg & 0x0f);
      fc->cart->setprg16(0xC000, 0);
    }
  }

  void UNLD2000Write(DECLFW_ARGS) {
    //  FCEU_printf("write %04x:%04x\n",A,V);
    switch (A) {
      case 0x5000:
	prg = V;
	Sync();
	break;
      case 0x5200:
	mirr = (V & 1) ^ 1;
	prgmode = V & 4;
	Sync();
	break;
	//    default: FCEU_printf("write %04x:%04x\n",A,V);
    }
  }

  DECLFR_RET UNLD2000Read(DECLFR_ARGS) {
    if (prg & 0x40)
      return fc->X->DB;
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }

  void Power() override {
    prg = prgmode = 0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, [](DECLFR_ARGS) {
      return ((UNLD2000*)fc->fceu->cartiface)->UNLD2000Read(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4020, 0x5FFF, [](DECLFW_ARGS) {
      ((UNLD2000*)fc->fceu->cartiface)->UNLD2000Write(DECLFW_FORWARD);
    });
  }

  void UNLAX5705IRQ() {
    if (fc->ppu->scanline > 174)
      fc->cart->setchr4(0x0000, 1);
    else
      fc->cart->setchr4(0x0000, 0);
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLD2000 *)fc->fceu->cartiface)->Sync();
  }

  UNLD2000(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((UNLD2000 *)fc->fceu->cartiface)->UNLAX5705IRQ();
    };
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({
      {&prg, 1, "REGS"}, {&mirr, 1, "MIRR"}, {&prgmode, 1, "MIRR"}});
  }
};
}

CartInterface *UNLD2000_Init(FC *fc, CartInfo *info) {
  return new UNLD2000(fc, info);
}
