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
 */

#include "mapinc.h"

namespace {
struct UNL8157 : public CartInterface {
  uint16 cmdreg = 0;
  uint8 invalid_data = 0;

  void Sync() {
    fc->cart->setprg16r((cmdreg & 0x060) >> 5, 0x8000,
			(cmdreg & 0x01C) >> 2);
    fc->cart->setprg16r((cmdreg & 0x060) >> 5, 0xC000,
			(cmdreg & 0x200) ? (~0) : 0);
    fc->cart->setmirror(((cmdreg & 2) >> 1) ^ 1);
  }

  DECLFR_RET UNL8157Read(DECLFR_ARGS) {
    if (invalid_data && cmdreg & 0x100)
      return 0xFF;
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }

  void UNL8157Write(DECLFW_ARGS) {
    cmdreg = A;
    Sync();
  }

  void Power() override {
    fc->cart->setchr8(0);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((UNL8157*)fc->fceu->cartiface)->UNL8157Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, [](DECLFR_ARGS) {
      return ((UNL8157*)fc->fceu->cartiface)->UNL8157Read(DECLFR_FORWARD);
    });
    cmdreg = 0x200;
    invalid_data = 1;
    Sync();
  }

  void Reset() override {
    cmdreg = 0;
    invalid_data ^= 1;
    Sync();
  }

  static void UNL8157Restore(FC *fc, int version) {
    ((UNL8157*)fc->fceu->cartiface)->Sync();
  }

  UNL8157(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = UNL8157Restore;
    fc->state->AddExVec({{&invalid_data, 1, "INVD"},
	                 {&cmdreg, 2, "CREG"}});
  }

};
}

CartInterface *UNL8157_Init(FC *fc, CartInfo *info) {
  return new UNL8157(fc, info);
}
