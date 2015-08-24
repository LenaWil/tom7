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
 * BMC 42-in-1 reset switch
 */

#include "mapinc.h"

namespace {
struct BMC13in1JY110 : public CartInterface {
  uint8 bank_mode = 0;
  uint8 bank_value = 0;
  uint8 prgb[4] = {};

  void Sync() {
    // FCEU_printf("%02x: %02x %02x\n", bank_mode, bank_value, prgb[0]);
    switch (bank_mode & 7) {
      case 0: fc->cart->setprg32(0x8000, bank_value & 7); break;
      case 1:
	fc->cart->setprg16(0x8000, ((8 + (bank_value & 7)) >> 1) + prgb[1]);
	fc->cart->setprg16(0xC000, (bank_value & 7) >> 1);
      case 4: fc->cart->setprg32(0x8000, 8 + (bank_value & 7)); break;
      case 5:
	fc->cart->setprg16(0x8000, ((8 + (bank_value & 7)) >> 1) + prgb[1]);
	fc->cart->setprg16(0xC000, ((8 + (bank_value & 7)) >> 1) + prgb[3]);
      case 2:
	fc->cart->setprg8(0x8000, prgb[0] >> 2);
	fc->cart->setprg8(0xa000, prgb[1]);
	fc->cart->setprg8(0xc000, prgb[2]);
	fc->cart->setprg8(0xe000, ~0);
	break;
      case 3:
	fc->cart->setprg8(0x8000, prgb[0]);
	fc->cart->setprg8(0xa000, prgb[1]);
	fc->cart->setprg8(0xc000, prgb[2]);
	fc->cart->setprg8(0xe000, prgb[3]);
	break;
    }
  }

  void BMC13in1JY110Write(DECLFW_ARGS) {
    // FCEU_printf("%04x:%04x\n", A, V);
    switch (A) {
      case 0x8000:
      case 0x8001:
      case 0x8002:
      case 0x8003: prgb[A & 3] = V; break;
      case 0xD000: bank_mode = V; break;
      case 0xD001: fc->cart->setmirror(V & 3);
      case 0xD002: break;
      case 0xD003: bank_value = V; break;
    }
    Sync();
  }

  void Power() override {
    prgb[0] = prgb[1] = prgb[2] = prgb[3] = 0;
    bank_mode = 0;
    bank_value = 0;
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(0);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((BMC13in1JY110*)fc->fceu->cartiface)->
	  BMC13in1JY110Write(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  static void StateRestore(FC *fc, int version) {
    ((BMC13in1JY110 *)fc->fceu->cartiface)->Sync();
  }

  BMC13in1JY110(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
  }
};
}

CartInterface *BMC13in1JY110_Init(FC *fc, CartInfo *info) {
  return new BMC13in1JY110(fc, info);
}
