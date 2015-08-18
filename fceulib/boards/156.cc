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

namespace {
struct Mapper156 : public CartInterface {
  uint8 chrlo[8] = {}, chrhi[8] = {}, prg = 0, mirr = 0, mirrisused = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    for (uint32 i = 0; i < 8; i++)
      fc->cart->setchr1(i << 10, chrlo[i] | (chrhi[i] << 8));
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg16(0x8000, prg);
    fc->cart->setprg16(0xC000, ~0);
    if (mirrisused)
      fc->cart->setmirror(mirr ^ 1);
    else
      fc->cart->setmirror(MI_0);
  }

  void M156Write(DECLFW_ARGS) {
    switch (A) {
      case 0xC000:
      case 0xC001:
      case 0xC002:
      case 0xC003:
	chrlo[A & 3] = V;
	Sync();
	break;
      case 0xC004:
      case 0xC005:
      case 0xC006:
      case 0xC007:
	chrhi[A & 3] = V;
	Sync();
	break;
      case 0xC008:
      case 0xC009:
      case 0xC00A:
      case 0xC00B:
	chrlo[4 + (A & 3)] = V;
	Sync();
	break;
      case 0xC00C:
      case 0xC00D:
      case 0xC00E:
      case 0xC00F:
	chrhi[4 + (A & 3)] = V;
	Sync();
	break;
      case 0xC010:
	prg = V;
	Sync();
	break;
      case 0xC014:
	mirr = V;
	mirrisused = 1;
	Sync();
	break;
    }
  }

  void Reset() override {
    for (uint32 i = 0; i < 8; i++) {
      chrlo[i] = 0;
      chrhi[i] = 0;
    }
    prg = 0;
    mirr = 0;
    mirrisused = 0;
  }

  void Power() override {
    Reset();
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0xC000, 0xCFFF, [](DECLFW_ARGS) {
      ((Mapper156*)fc->fceu->cartiface)->M156Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper156*)fc->fceu->cartiface)->Sync();
  }

  Mapper156(FC *fc, CartInfo *info) : CartInterface(fc) {
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&prg, 1, "PREG"},
			 {chrlo, 8, "CRGL"},
			 {chrhi, 8, "CRGH"},
			 {&mirr, 1, "MIRR"}});
  }

};
}

CartInterface *Mapper156_Init(FC *fc, CartInfo *info) {
  return new Mapper156(fc, info);
}
