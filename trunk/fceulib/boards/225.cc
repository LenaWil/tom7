/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2011 CaH4e3
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

namespace {
struct Mapper225 : public CartInterface {
  uint8 prot[4] = {}, prg = 0, mode = 0, chr = 0, mirr = 0;

  void Sync() {
    if (mode) {
      fc->cart->setprg16(0x8000, prg);
      fc->cart->setprg16(0xC000, prg);
    } else {
      fc->cart->setprg32(0x8000, prg >> 1);
    }
    fc->cart->setchr8(chr);
    fc->cart->setmirror(mirr);
  }

  void M225Write(DECLFW_ARGS) {
    uint32 bank = (A >> 14) & 1;
    mirr = (A >> 13) & 1;
    mode = (A >> 12) & 1;
    chr = (A & 0x3f) | (bank << 6);
    prg = ((A >> 6) & 0x3f) | (bank << 6);
    Sync();
  }

  void M225LoWrite(DECLFW_ARGS) {}

  DECLFR_RET M225LoRead(DECLFR_ARGS) {
    return 0;
  }

  void Power() override {
    prg = 0;
    mode = 0;
    Sync();
    fc->fceu->SetReadHandler(0x5000, 0x5fff, [](DECLFR_ARGS) {
      return ((Mapper225*)fc->fceu->cartiface)->
	M225LoRead(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5000, 0x5fff, [](DECLFW_ARGS) {
      ((Mapper225*)fc->fceu->cartiface)->M225LoWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper225*)fc->fceu->cartiface)->M225Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    prg = 0;
    mode = 0;
    Sync();
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper225 *)fc->fceu->cartiface)->Sync();
  }

  Mapper225(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{prot, 4, "PROT"}, {&prg, 1, "PRG0"},
			 {&chr, 1, "CHR0"}, {&mode, 1, "MODE"},
			 {&mirr, 1, "MIRR"}});
  }
};
}

CartInterface *Mapper225_Init(FC *fc, CartInfo *info) {
  return new Mapper225(fc, info);
}
