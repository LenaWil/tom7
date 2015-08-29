/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2006 CaH4e3
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
 *
 */

#include "mapinc.h"

namespace {
struct UNLEDU2000 : public CartInterface {
  uint8 *WRAM = nullptr;
  uint8 reg = 0;

  void Sync() {
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, (reg & 0xC0) >> 6);
    fc->cart->setprg32(0x8000, reg & 0x1F);
    //  fc->cart->setmirror(((reg&0x20)>>5));
  }

  void UNLEDU2000HiWrite(DECLFW_ARGS) {
    //  FCEU_printf("%04x:%02x\n",A,V);
    reg = V;
    Sync();
  }

  void Power() override {
    fc->cart->setmirror(MI_0);
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0xFFFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((UNLEDU2000*)fc->fceu->cartiface)->UNLEDU2000HiWrite(DECLFW_FORWARD);
    });
    reg = 0;
    Sync();
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void UNLEDU2000Restore(FC *fc, int version) {
    ((UNLEDU2000 *)fc->fceu->cartiface)->Sync();
  }

  UNLEDU2000(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = UNLEDU2000Restore;
    WRAM = (uint8 *)FCEU_gmalloc(32768);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, 32768, 1);
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = 32768;
    }
    fc->state->AddExState(WRAM, 32768, 0, "WRAM");
    fc->state->AddExVec({{&reg, 1, "REGS"}});
    
  }
};
}

CartInterface *UNLEDU2000_Init(FC *fc, CartInfo *info) {
  return new UNLEDU2000(fc, info);
}
