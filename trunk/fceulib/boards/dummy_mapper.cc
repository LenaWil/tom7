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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include "mapinc.h"

// More like "example mapper" than "dummy" -- this one isn't even
// referenced from anywhere.

/*
  static constexpr int WRAMSIZE = 8192;
  static constexpr int CHRRAMSIZE = 8192;
*/

namespace {
struct MapperNNN : public CartInterface {
  uint8 reg[8] = {};
  uint8 IRQa = 0;
  int16 IRQCount = 0, IRQLatch = 0;
  /*
  static uint8 *WRAM=nullptr;
  static uint8 *CHRRAM=nullptr;
  */

  void Sync() {}

  void MNNNWrite(DECLFW_ARGS) {}

  void Power() override {
    //	fc->fceu->SetReadHandler(0x6000,0x7fff,CartBR);
    //	fc->fceu->SetWriteHandler(0x6000,0x7fff,CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((MapperNNN*)fc->fceu->cartiface)->MNNNWrite(DECLFW_FORWARD);
    });
  }

  void Reset() override {}

  /*
  static void Close() override {
    free(WRAM);
    free(CHRRAM);
    WRAM = CHRRAM = nullptr;
  }
  */

  void MNNNIRQHook() {
    fc->X->IRQBegin(FCEU_IQEXT);
  }

  static void StateRestore(FC *fc, int version) {
    ((MapperNNN*)fc->fceu->cartiface)->Sync();
  }

  MapperNNN(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((MapperNNN*)fc->fceu->cartiface)->MNNNIRQHook();
    }
    fc->fceu->GameStateRestore = StateRestore;
    /*
      CHRRAMSIZE = 8192;
      CHRRAM = (uint8*)FCEU_gmalloc(CHRRAMSIZE);
      SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
      fc->state->AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");
    */
    /*
      WRAM = (uint8*)FCEU_gmalloc(WRAMSIZE);
      SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
      fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
      if (info->battery) {
	info->SaveGame[0] = WRAM;
	info->SaveGameLen[0] = WRAMSIZE;
      }
    */
    fc->state->AddExVec({{reg, 8, "REGS"},
			 {&IRQa, 1, "IRQA"},
			 {&IRQCount, 2, "IRQC"},
			 {&IRQLatch, 2, "IRQL"}});
  }

};
}

CartInterface *MapperNNN_Init(FC *fc, CartInfo *info) {
  return new MapperNNN(fc, info);
}
