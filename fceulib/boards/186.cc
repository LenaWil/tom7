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
 *
 * Family Study Box by Fukutake Shoten
 */

#include "mapinc.h"

namespace {
struct Mapper186 : public CartInterface {
  uint8 SWRAM[2816] = {};
  uint8 *WRAM = nullptr;
  uint8 regs[4] = {};

  void Sync() {
    fc->cart->setprg8r(0x10, 0x6000, regs[0] >> 6);
    fc->cart->setprg16(0x8000, regs[1]);
    fc->cart->setprg16(0xc000, 0);
  }

  void M186Write(DECLFW_ARGS) {
    if (A & 0x4203) regs[A & 3] = V;
    Sync();
  }

  DECLFR_RET M186Read(DECLFR_ARGS) {
    switch (A) {
      case 0x4200: return 0x00; break;
      case 0x4201: return 0x00; break;
      case 0x4202: return 0x40; break;
      case 0x4203: return 0x00; break;
    }
    return 0xFF;
  }

  DECLFR_RET ASWRAM(DECLFR_ARGS) {
    return SWRAM[A - 0x4400];
  }
  void BSWRAM(DECLFW_ARGS) {
    SWRAM[A - 0x4400] = V;
  }

  void Power() override {
    fc->cart->setchr8(0);
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0xFFFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x4200, 0x43FF, [](DECLFR_ARGS) {
	return ((Mapper186*)fc->fceu->cartiface)->M186Read(DECLFR_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x4200, 0x43FF, [](DECLFW_ARGS) {
	((Mapper186*)fc->fceu->cartiface)->M186Write(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x4400, 0x4EFF, [](DECLFR_ARGS) {
	return ((Mapper186*)fc->fceu->cartiface)->ASWRAM(DECLFR_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x4400, 0x4EFF, [](DECLFW_ARGS) {
	((Mapper186*)fc->fceu->cartiface)->BSWRAM(DECLFW_FORWARD);
      });
    regs[0] = regs[1] = regs[2] = regs[3];
    Sync();
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void M186Restore(FC *fc, int version) {
    ((Mapper186 *)fc->fceu->cartiface)->Sync();
  }

  Mapper186(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = M186Restore;
    WRAM = (uint8 *)FCEU_gmalloc(32768);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, 32768, 1);
    fc->state->AddExState(WRAM, 32768, 0, "WRAM");
    fc->state->AddExVec({{regs, 4, "DREG"}, {SWRAM, 2816, "SWRM"}});
  }
};
}

CartInterface *Mapper186_Init(FC *fc, CartInfo *info) {
  return new Mapper186(fc, info);
}
