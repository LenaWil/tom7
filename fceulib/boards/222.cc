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
 * (VRC4 mapper)
 */

#include "mapinc.h"

namespace {
struct Mapper222 : public CartInterface {
  uint8 IRQCount = 0;
  uint8 IRQa = 0;
  uint8 prg_reg[2] = {};
  uint8 chr_reg[8] = {};
  uint8 mirr = 0;

  void M222IRQ() {
    if (IRQa) {
      IRQCount++;
      if (IRQCount >= 238) {
	fc->X->IRQBegin(FCEU_IQEXT);
	//      IRQa=0;
      }
    }
  }

  void Sync() {
    fc->cart->setprg8(0x8000, prg_reg[0]);
    fc->cart->setprg8(0xA000, prg_reg[1]);
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chr_reg[i]);
    fc->cart->setmirror(mirr ^ 1);
  }

  void M222Write(DECLFW_ARGS) {
    switch (A & 0xF003) {
      case 0x8000: prg_reg[0] = V; break;
      case 0x9000: mirr = V & 1; break;
      case 0xA000: prg_reg[1] = V; break;
      case 0xB000: chr_reg[0] = V; break;
      case 0xB002: chr_reg[1] = V; break;
      case 0xC000: chr_reg[2] = V; break;
      case 0xC002: chr_reg[3] = V; break;
      case 0xD000: chr_reg[4] = V; break;
      case 0xD002: chr_reg[5] = V; break;
      case 0xE000: chr_reg[6] = V; break;
      case 0xE002:
	chr_reg[7] = V;
	break;
      //    case 0xF000: FCEU_printf("%04x:%02x %d\n",A,V,scanline); IRQa=V;
      //    if(!V)IRQPre=0; fc->X->IRQEnd(FCEU_IQEXT); break;
      //    case 0xF001: FCEU_printf("%04x:%02x %d\n",A,V,scanline); IRQCount=V;
      //    break;
      //    case 0xF002: FCEU_printf("%04x:%02x %d\n",A,V,scanline); break;
      //    case 0xD001: IRQa=V; fc->X->IRQEnd(FCEU_IQEXT);
      //    FCEU_printf("%04x:%02x %d\n",A,V,scanline); break;
      //    case 0xC001: IRQPre=16; FCEU_printf("%04x:%02x %d\n",A,V,scanline);
      //    break;
      case 0xF000:
	IRQa = IRQCount = V;
	if (fc->ppu->scanline < 240)
	  IRQCount -= 8;
	else
	  IRQCount += 4;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
    }
    Sync();
  }

  void Power() override {
    fc->cart->setprg16(0xC000, ~0);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper222*)fc->fceu->cartiface)->M222Write(DECLFW_FORWARD);
      });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper222 *)fc->fceu->cartiface)->Sync();
  }

  Mapper222(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((Mapper222 *)fc->fceu->cartiface)->M222IRQ();
    };
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&IRQCount, 1, "IRQC"}, {&IRQa, 1, "IRQA"},
			 {prg_reg, 2, "PRG0"},    {chr_reg, 8, "CHR0"},
			 {&mirr, 1, "MIRR"}});
  }
};
}

CartInterface *Mapper222_Init(FC *fc, CartInfo *info) {
  return new Mapper222(fc, info);
}
