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
 * 700in1 and 400in1 carts
 */

#include "mapinc.h"

namespace {
struct UNLN625092 : public CartInterface {
  uint16 cmd = 0, bank = 0;
  uint16 ass = 0;

  void Sync() {
    fc->cart->setmirror((cmd & 1) ^ 1);
    fc->cart->setchr8(0);
    if (cmd & 2) {
      if (cmd & 0x100) {
	fc->cart->setprg16(0x8000, ((cmd & 0xfc) >> 2) | bank);
	fc->cart->setprg16(0xC000, ((cmd & 0xfc) >> 2) | 7);
      } else {
	fc->cart->setprg16(0x8000, ((cmd & 0xfc) >> 2) | (bank & 6));
	fc->cart->setprg16(0xC000, ((cmd & 0xfc) >> 2) | ((bank & 6) | 1));
      }
    } else {
      fc->cart->setprg16(0x8000, ((cmd & 0xfc) >> 2) | bank);
      fc->cart->setprg16(0xC000, ((cmd & 0xfc) >> 2) | bank);
    }
  }

  void UNLN625092WriteCommand(DECLFW_ARGS) {
    cmd = A;
    if (A == 0x80F8) {
      fc->cart->setprg16(0x8000, ass);
      fc->cart->setprg16(0xC000, ass);
    } else {
      Sync();
    }
  }

  void UNLN625092WriteBank(DECLFW_ARGS) {
    bank = A & 7;
    Sync();
  }

  void Power() override {
    cmd = 0;
    bank = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
	((UNLN625092*)fc->fceu->cartiface)->
	  UNLN625092WriteCommand(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0xC000, 0xFFFF, [](DECLFW_ARGS) {
	((UNLN625092*)fc->fceu->cartiface)->
	  UNLN625092WriteBank(DECLFW_FORWARD);
      });
  }

  void Reset() override {
    cmd = 0;
    bank = 0;
    ass++;
    // FCEU_printf("%04x\n", ass);
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLN625092*)fc->fceu->cartiface)->Sync();
  }

  UNLN625092(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&cmd, 2, "CMD0"}, {&bank, 2, "BANK"}});
  }
};
}

CartInterface *UNLN625092_Init(FC *fc, CartInfo *info) {
  return new UNLN625092(fc, info);
}
