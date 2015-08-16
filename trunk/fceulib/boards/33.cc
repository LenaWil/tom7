/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2012 CaH4e3
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
struct Mapper33 : public CartInterface {
  const bool is48;
  uint8 regs[8] = {}, mirr = 0;
  uint8 IRQa = 0;
  int16 IRQCount = 0, IRQLatch = 0;

  void Sync() {
    fc->cart->setmirror(mirr);
    fc->cart->setprg8(0x8000, regs[0]);
    fc->cart->setprg8(0xA000, regs[1]);
    fc->cart->setprg8(0xC000, ~1);
    fc->cart->setprg8(0xE000, ~0);
    fc->cart->setchr2(0x0000, regs[2]);
    fc->cart->setchr2(0x0800, regs[3]);
    fc->cart->setchr1(0x1000, regs[4]);
    fc->cart->setchr1(0x1400, regs[5]);
    fc->cart->setchr1(0x1800, regs[6]);
    fc->cart->setchr1(0x1C00, regs[7]);
  }

  void M33Write(DECLFW_ARGS) {
    A &= 0xF003;
    switch (A) {
      case 0x8000:
	regs[0] = V & 0x3F;
	if (!is48) mirr = ((V >> 6) & 1) ^ 1;
	Sync();
	break;
      case 0x8001:
	regs[1] = V & 0x3F;
	Sync();
	break;
      case 0x8002:
	regs[2] = V;
	Sync();
	break;
      case 0x8003:
	regs[3] = V;
	Sync();
	break;
      case 0xA000:
	regs[4] = V;
	Sync();
	break;
      case 0xA001:
	regs[5] = V;
	Sync();
	break;
      case 0xA002:
	regs[6] = V;
	Sync();
	break;
      case 0xA003:
	regs[7] = V;
	Sync();
	break;
    }
  }

  void M48Write(DECLFW_ARGS) {
    switch (A & 0xF003) {
    case 0xC000: IRQLatch = V; break;
    case 0xC001: IRQCount = IRQLatch; break;
    case 0xC003:
      IRQa = 0;
      fc->X->IRQEnd(FCEU_IQEXT);
      break;
    case 0xC002: IRQa = 1; break;
    case 0xE000:
      mirr = ((V >> 6) & 1) ^ 1;
      Sync();
      break;
    }
  }

  void Power() override {
    if (is48) {
      Sync();
      fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
      fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
	return ((Mapper33*)fc->fceu->cartiface)->
	  M33Write(DECLFW_FORWARD);
      });
      fc->fceu->SetWriteHandler(0xC000, 0xFFFF, [](DECLFW_ARGS) {
	return ((Mapper33*)fc->fceu->cartiface)->
	  M48Write(DECLFW_FORWARD);
      });
    } else {
      Sync();
      fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
      fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	return ((Mapper33*)fc->fceu->cartiface)->
	  M33Write(DECLFW_FORWARD);
      });
    }
  }

  void M48IRQ() {
    if (IRQa) {
      IRQCount++;
      if (IRQCount == 0x100) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
      }
    }
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper33*)fc->fceu->cartiface)->Sync();
  }

  Mapper33(FC *fc, CartInfo *info, bool is48)
    : CartInterface(fc), is48(is48) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{regs, 8, "PREG"},
	{&mirr, 1, "MIRR"},
	{&IRQa, 1, "IRQA"},
	{&IRQCount, 2, "IRQC"},
	{&IRQLatch, 2, "IRQL"}});
    if (is48) {
      fc->ppu->GameHBIRQHook = [](FC *fc) {
	((Mapper33*)fc->fceu->cartiface)->M48IRQ();
      };
    }
  }

};
}
  
CartInterface *Mapper33_Init(FC *fc, CartInfo *info) {
  return new Mapper33(fc, info, false);
}

CartInterface *Mapper48_Init(FC *fc, CartInfo *info) {
  return new Mapper33(fc, info, true);
}
