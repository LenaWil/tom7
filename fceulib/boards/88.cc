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
struct Mapper88 : public CartInterface {
  uint8 reg[8] = {};
  uint8 mirror = 0, cmd = 0, is154 = false;

  void Sync() {
    fc->cart->setchr2(0x0000, reg[0] >> 1);
    fc->cart->setchr2(0x0800, reg[1] >> 1);
    fc->cart->setchr1(0x1000, reg[2] | 0x40);
    fc->cart->setchr1(0x1400, reg[3] | 0x40);
    fc->cart->setchr1(0x1800, reg[4] | 0x40);
    fc->cart->setchr1(0x1C00, reg[5] | 0x40);
    fc->cart->setprg8(0x8000, reg[6]);
    fc->cart->setprg8(0xA000, reg[7]);
  }

  void MSync() {
    if (is154) fc->cart->setmirror(MI_0 + (mirror & 1));
  }

  void M88Write(DECLFW_ARGS) {
    switch (A & 0x8001) {
      case 0x8000:
	cmd = V & 7;
	mirror = V >> 6;
	MSync();
	break;
      case 0x8001:
	reg[cmd] = V;
	Sync();
	break;
    }
  }

  void Power() {
    fc->cart->setprg16(0xC000, ~0);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper88*)fc->fceu->cartiface)->M88Write(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    Mapper88 *me = ((Mapper88*)fc->fceu->cartiface);
    me->Sync();
    me->MSync();
  }

  Mapper88(FC *fc, CartInfo *info, bool is154) : CartInterface(fc),
						 is154(is154) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&cmd, 1, "CMD0"}, {&mirror, 1, "MIRR"}, {reg, 8, "REGS"}});
  }
};
}

CartInterface *Mapper88_Init(FC *fc, CartInfo *info) {
  return new Mapper88(fc, info, false);
}

CartInterface *Mapper154_Init(FC *fc, CartInfo *info) {
  return new Mapper88(fc, info, true);
}
