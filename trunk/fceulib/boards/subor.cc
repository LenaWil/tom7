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
struct Mapper16X : public CartInterface {
  const uint8 mode = 0;
  uint8 DRegs[4] = {};

  void Sync() {
    int base, bank;
    base = ((DRegs[0] ^ DRegs[1]) & 0x10) << 1;
    bank = (DRegs[2] ^ DRegs[3]) & 0x1f;

    if (DRegs[1] & 0x08) {
      bank &= 0xfe;
      if (mode == 0) {
	fc->cart->setprg16(0x8000, base + bank + 1);
	fc->cart->setprg16(0xC000, base + bank + 0);
      } else {
	fc->cart->setprg16(0x8000, base + bank + 0);
	fc->cart->setprg16(0xC000, base + bank + 1);
      }
    } else {
      if (DRegs[1] & 0x04) {
	fc->cart->setprg16(0x8000, 0x1f);
	fc->cart->setprg16(0xC000, base + bank);
      } else {
	fc->cart->setprg16(0x8000, base + bank);
	if (mode == 0)
	  fc->cart->setprg16(0xC000, 0x20);
	else
	  fc->cart->setprg16(0xC000, 0x07);
      }
    }
  }

  void Mapper167_write(DECLFW_ARGS) {
    DRegs[(A >> 13) & 0x03] = V;
    Sync();
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper16X *)fc->fceu->cartiface)->Sync();
  }

  Mapper16X(FC *fc, CartInfo *info, int mode) : CartInterface(fc),
						mode(mode) {
    DRegs[0] = DRegs[1] = DRegs[2] = DRegs[3] = 0;
    Sync();
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper16X*)fc->fceu->cartiface)->Mapper167_write(DECLFW_FORWARD);
    });
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{DRegs, 4, "DREG"}});
  }
};
}

CartInterface *Mapper166_Init(FC *fc, CartInfo *info) {
  return new Mapper16X(fc, info, 1);
}

CartInterface *Mapper167_Init(FC *fc, CartInfo *info) {
  return new Mapper16X(fc, info, 0);
}
