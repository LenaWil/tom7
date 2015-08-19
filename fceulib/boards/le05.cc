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
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

namespace {
struct LE05 : public CartInterface {
  uint8 chr = 0;

  void Sync() {
    fc->cart->setprg2r(0, 0xE000, 0);
    fc->cart->setprg2r(0, 0xE800, 0);
    fc->cart->setprg2r(0, 0xF000, 0);
    fc->cart->setprg2r(0, 0xF800, 0);

    fc->cart->setprg8r(1, 0x6000, 3);
    fc->cart->setprg8r(1, 0x8000, 0);
    fc->cart->setprg8r(1, 0xA000, 1);
    fc->cart->setprg8r(1, 0xC000, 2);

    fc->cart->setchr8(chr & 1);
    fc->cart->setmirror(MI_V);
  }

  void LE05Write(DECLFW_ARGS) {
    chr = V;
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((LE05*)fc->fceu->cartiface)->LE05Write(DECLFW_FORWARD);
    });
  }

  LE05(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{&chr, 1, "CHR0"}});
  }
};
}

CartInterface *LE05_Init(FC *fc, CartInfo *info) {
  return new LE05(fc, info);
}
