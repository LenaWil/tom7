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
 *
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper15 : public CartInterface {
  uint16 latcha = 0;
  uint8 latchd = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setmirror(((latchd >> 6) & 1) ^ 1);
    switch (latcha) {
      case 0x8000:
	for (int i = 0; i < 4; i++)
	  fc->cart->setprg8(0x8000 + (i << 13),
			    (((latchd & 0x7F) << 1) + i) ^ (latchd >> 7));
	break;
      case 0x8002:
	for (int i = 0; i < 4; i++)
	  fc->cart->setprg8(0x8000 + (i << 13),
			    ((latchd & 0x7F) << 1) + (latchd >> 7));
	break;
      case 0x8001:
      case 0x8003:
	for (int i = 0; i < 4; i++) {
	  unsigned int b = latchd & 0x7F;
	  if (i >= 2 && !(latcha & 0x2)) i = 0x7F;
	  fc->cart->setprg8(0x8000 + (i << 13),
			    (i & 1) + ((b << 1) ^ (latchd >> 7)));
	}
	break;
    }
  }

  void M15Write(DECLFW_ARGS) {
    latcha = A;
    latchd = V;
    //  printf("%04X = %02X\n",A,V);
    Sync();
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper15*)fc->fceu->cartiface)->Sync();
  }

  void Power() override {
    latcha = 0x8000;
    latchd = 0;
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper15*)fc->fceu->cartiface)->M15Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    Sync();
  }

  void Reset() override {
    latcha = 0x8000;
    latchd = 0;
    Sync();
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  Mapper15(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    fc->state->AddExVec({{&latcha, 2, "AREG"}, {&latchd, 1, "DREG"}});
  }

};
}

CartInterface *Mapper15_Init(FC *fc, CartInfo *info) {
  return new Mapper15(fc, info);
}
