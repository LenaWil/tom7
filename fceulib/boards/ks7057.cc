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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * FDS Conversion
 *
 */

#include "mapinc.h"

namespace {
struct UNLKS7057 : public CartInterface {
  uint8 reg[8] = {}, mirror = 0;

  void Sync() {
    fc->cart->setprg2(0x6000, reg[4]);
    fc->cart->setprg2(0x6800, reg[5]);
    fc->cart->setprg2(0x7000, reg[6]);
    fc->cart->setprg2(0x7800, reg[7]);
    fc->cart->setprg2(0x8000, reg[0]);
    fc->cart->setprg2(0x8800, reg[1]);
    fc->cart->setprg2(0x9000, reg[2]);
    fc->cart->setprg2(0x9800, reg[3]);
    fc->cart->setprg8(0xA000, 0xd);
    fc->cart->setprg16(0xC000, 7);
    fc->cart->setchr8(0);
    fc->cart->setmirror(mirror);
  }

  void UNLKS7057Write(DECLFW_ARGS) {
    switch (A & 0xF003) {
      case 0x8000:
      case 0x8001:
      case 0x8002:
      case 0x8003:
      case 0x9000:
      case 0x9001:
      case 0x9002:
      case 0x9003:
	mirror = V & 1;
	Sync();
	break;
      case 0xB000:
	reg[0] = (reg[0] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xB001:
	reg[0] = (reg[0] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xB002:
	reg[1] = (reg[1] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xB003:
	reg[1] = (reg[1] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xC000:
	reg[2] = (reg[2] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xC001:
	reg[2] = (reg[2] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xC002:
	reg[3] = (reg[3] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xC003:
	reg[3] = (reg[3] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xD000:
	reg[4] = (reg[4] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xD001:
	reg[4] = (reg[4] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xD002:
	reg[5] = (reg[5] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xD003:
	reg[5] = (reg[5] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xE000:
	reg[6] = (reg[6] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xE001:
	reg[6] = (reg[6] & 0x0F) | (V << 4);
	Sync();
	break;
      case 0xE002:
	reg[7] = (reg[7] & 0xF0) | (V & 0x0F);
	Sync();
	break;
      case 0xE003:
	reg[7] = (reg[7] & 0x0F) | (V << 4);
	Sync();
	break;
    }
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((UNLKS7057*)fc->fceu->cartiface)->UNLKS7057Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    Sync();
  }

  UNLKS7057(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->state->AddExVec({{reg, 8, "PRG0"}, {&mirror, 1, "MIRR"}});
  }

};
}

CartInterface *UNLKS7057_Init(FC *fc, CartInfo *info) {
  return new UNLKS7057(fc, info);
}
