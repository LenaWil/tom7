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
 * Lethal Weapon (VRC4 mapper)
 */

#include "mapinc.h"

namespace {
struct UNLTF1201 : public CartInterface {
  uint8 prg0 = 0, prg1 = 0, mirr = 0, tfswap = 0;
  uint8 chr[8] = {};
  uint8 IRQCount = 0;
  uint8 IRQPre = 0;
  uint8 IRQa = 0;

  void SyncPrg() {
    if (tfswap & 3) {
      fc->cart->setprg8(0x8000, ~1);
      fc->cart->setprg8(0xC000, prg0);
    } else {
      fc->cart->setprg8(0x8000, prg0);
      fc->cart->setprg8(0xC000, ~1);
    }
    fc->cart->setprg8(0xA000, prg1);
    fc->cart->setprg8(0xE000, ~0);
  }

  void SyncChr() {
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chr[i]);
    fc->cart->setmirror(mirr ^ 1);
  }

  void StateRestore() {
    SyncPrg();
    SyncChr();
  }

  void UNLTF1201Write(DECLFW_ARGS) {
    A = (A & 0xF003) | ((A & 0xC) >> 2);
    if ((A >= 0xB000) && (A <= 0xE003)) {
      int ind = (((A >> 11) - 6) | (A & 1)) & 7;
      int sar = ((A & 2) << 1);
      chr[ind] = (chr[ind] & (0xF0 >> sar)) | ((V & 0x0F) << sar);
      SyncChr();
    } else {
      switch (A & 0xF003) {
	case 0x8000:
	  prg0 = V;
	  SyncPrg();
	  break;
	case 0xA000:
	  prg1 = V;
	  SyncPrg();
	  break;
	case 0x9000:
	  mirr = V & 1;
	  SyncChr();
	  break;
	case 0x9001:
	  tfswap = V & 3;
	  SyncPrg();
	  break;
	case 0xF000: IRQCount = ((IRQCount & 0xF0) | (V & 0xF)); break;
	case 0xF002: IRQCount = ((IRQCount & 0x0F) | ((V & 0xF) << 4)); break;
	case 0xF001:
	case 0xF003:
	  IRQa = V & 2;
	  fc->X->IRQEnd(FCEU_IQEXT);
	  if (fc->ppu->scanline < 240) IRQCount -= 8;
	  break;
      }
    }
  }

  void UNLTF1201IRQCounter() {
    if (IRQa) {
      IRQCount++;
      if (IRQCount == 237) {
	fc->X->IRQBegin(FCEU_IQEXT);
      }
    }
  }

  void Power() override {
    IRQPre = IRQCount = IRQa = 0;
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((UNLTF1201*)fc->fceu->cartiface)->UNLTF1201Write(DECLFW_FORWARD);
    });
    SyncPrg();
    SyncChr();
  }

  UNLTF1201(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((UNLTF1201 *)fc->fceu->cartiface)->UNLTF1201IRQCounter();
    };
    fc->fceu->GameStateRestore = [](FC *fc, int version) {
      ((UNLTF1201 *)fc->fceu->cartiface)->StateRestore();
    };
    fc->state->AddExVec({
      {&prg0, 1, "PRG0"}, {&prg0, 1, "PRG1"}, {&mirr, 1, "MIRR"},
      {&tfswap, 1, "SWAP"}, {chr, 8, "CHR0"}, {&IRQCount, 1, "IRQC"},
      {&IRQPre, 1, "IRQP"}, {&IRQa, 1, "IRQA"}});
  }
};
}

CartInterface *UNLTF1201_Init(FC *fc, CartInfo *info) {
  return new UNLTF1201(fc, info);
}
