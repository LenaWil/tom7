/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2009 CaH4e3
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

static constexpr uint8 bs_tbl[128] = {
  0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33,
  0x03, 0x13, 0x23, 0x33, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67,
  0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x03, 0x13, 0x23, 0x33,
  0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33, 0x03, 0x13, 0x23, 0x33,
  0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67,
  0x47, 0x67, 0x47, 0x67, 0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32,
  0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, 0x45, 0x67, 0x45, 0x67,
  0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67, 0x45, 0x67,
  0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32, 0x02, 0x12, 0x22, 0x32,
  0x00, 0x10, 0x20, 0x30, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67,
  0x47, 0x67, 0x47, 0x67, 0x47, 0x67, 0x47, 0x67,
};

static constexpr uint8 br_tbl[16] = {
  0x00, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20,
  0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
};

namespace {
struct UNLPEC586 : public CartInterface {
  uint8 reg[7] = {};
  uint8 *WRAM = nullptr;

  void Sync() {
    //  setchr4(0x0000,(reg[0]&0x80) >> 7);
    //  setchr4(0x1000,(reg[0]&0x80) >> 7);
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg16(0x8000, bs_tbl[reg[0] & 0x7f] >> 4);
    fc->cart->setprg16(0xc000, bs_tbl[reg[0] & 0x7f] & 0xf);
    fc->cart->setmirror(MI_V);
  }

  void UNLPEC586Write(DECLFW_ARGS) {
    reg[(A & 0x700) >> 8] = V;
    // FCEU_printf("bs %04x %02x\n", A, V);
    Sync();
  }

  DECLFR_RET UNLPEC586Read(DECLFR_ARGS) {
    // FCEU_printf("read %04x\n", A);
    return (fc->X->DB & 0xD8) | br_tbl[reg[4] >> 4];
  }

  void Power() override {
    reg[0] = 0x0E;
    Sync();
    fc->cart->setchr8(0);
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x5000, 0x5fff, [](DECLFW_ARGS) {
	((UNLPEC586*)fc->fceu->cartiface)->UNLPEC586Write(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x5000, 0x5fff, [](DECLFR_ARGS) {
	return ((UNLPEC586*)fc->fceu->cartiface)->
	  UNLPEC586Read(DECLFR_FORWARD);
      });
  }

  void UNLPEC586IRQ() {
    if (fc->ppu->scanline == 128) {
      fc->cart->setchr4(0x0000, 1);
      fc->cart->setchr4(0x1000, 0);
    } else {
      fc->cart->setchr4(0x0000, 0);
      fc->cart->setchr4(0x1000, 1);
    }
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLPEC586 *)fc->fceu->cartiface)->Sync();
  }

  UNLPEC586(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((UNLPEC586 *)fc->fceu->cartiface)->UNLPEC586IRQ();
    };
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({{reg, 2, "REGS"}});
  }
};
}

CartInterface *UNLPEC586_Init(FC *fc, CartInfo *info) {
  return new UNLPEC586(fc, info);
}
