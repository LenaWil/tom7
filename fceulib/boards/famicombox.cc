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

static constexpr int WRAMSIZE = 16384;

namespace {
struct SSSNROM : public CartInterface {
  uint8 regs[8] = {};
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setprg2r(0x10, 0x0800, 0);
    fc->cart->setprg2r(0x10, 0x1000, 1);
    fc->cart->setprg2r(0x10, 0x1800, 2);
    fc->cart->setprg8r(0x10, 0x6000, 1);
    fc->cart->setprg16(0x8000, 0);
    fc->cart->setprg16(0xC000, ~0);
    fc->cart->setchr8(0);
  }

  // static DECLFW(SSSNROMWrite)
  //{
  //  CartBW(A,V);
  //}

  void SSSNROMWrite(DECLFW_ARGS) {
    // FCEU_printf("write %04x %02x\n",A,V);
    // regs[A&7] = V;
  }

  DECLFR_RET SSSNROMRead(DECLFR_ARGS) {
    // FCEU_printf("read %04x\n",A);
    switch (A & 7) {
      case 0: return regs[0] = 0xff;  // clear all exceptions
      case 2: return 0xc0;  // DIP selftest + freeplay
      case 3:
	return 0x00;  // 0, 1 - attract
      // 2
      // 4    - menu
      // 8    - self check and game casette check
      // 10   - lock?
      // 20   - game title & count display
      case 7: return 0x22;  // TV type, key not turned, relay B
      default: return 0;
    }
  }

  void Power() override {
    regs[0] = regs[1] = regs[2] = regs[3] = regs[4] = regs[5] = regs[6] = 0;
    regs[7] = 0xff;
    Sync();
    memset(WRAM, 0x00, WRAMSIZE);
    //  fc->fceu->SetWriteHandler(0x0000,0x1FFF,SSSNROMRamWrite);
    fc->fceu->SetReadHandler(0x0800, 0x1FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x0800, 0x1FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x5000, 0x5FFF, [](DECLFR_ARGS) {
      return ((SSSNROM*)fc->fceu->cartiface)->SSSNROMRead(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      ((SSSNROM*)fc->fceu->cartiface)->SSSNROMWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  void Reset() override {
    regs[1] = regs[2] = regs[3] = regs[4] = regs[5] = regs[6] = 0;
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  void SSSNROMIRQHook() {
    //  fc->X->IRQBegin(FCEU_IQEXT);
  }

  static void StateRestore(FC *fc, int version) {
    ((SSSNROM *)fc->fceu->cartiface)->Sync();
  }

  SSSNROM(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((SSSNROM *)fc->fceu->cartiface)->SSSNROMIRQHook();
    };
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);

    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    fc->state->AddExVec({{regs, 8, "REGS"}});
  }
};
}

CartInterface *SSSNROM_Init(FC *fc, CartInfo *info) {
  return new SSSNROM(fc, info);
}
