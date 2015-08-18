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
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper68 : public CartInterface {

  uint8 chr_reg[4] = {};
  uint8 kogame = 0, prg_reg = 0, nt1 = 0, nt2 = 0, mirr = 0;

  uint8 *WRAM = nullptr;
  uint32 count = 0;

  void M68NTfix() {
    if ((!fc->unif->UNIFchrrama) && (mirr & 0x10)) {
      fc->ppu->PPUNTARAM = 0;
      switch (mirr & 3) {
	case 0:
	  fc->ppu->vnapage[0] = fc->ppu->vnapage[2] =
	      fc->cart->CHRptr[0] +
	      (((nt1 | 128) & fc->cart->CHRmask1[0]) << 10);
	  fc->ppu->vnapage[1] = fc->ppu->vnapage[3] =
	      fc->cart->CHRptr[0] +
	      (((nt2 | 128) & fc->cart->CHRmask1[0]) << 10);
	  break;
	case 1:
	  fc->ppu->vnapage[0] = fc->ppu->vnapage[1] =
	      fc->cart->CHRptr[0] +
	      (((nt1 | 128) & fc->cart->CHRmask1[0]) << 10);
	  fc->ppu->vnapage[2] = fc->ppu->vnapage[3] =
	      fc->cart->CHRptr[0] +
	      (((nt2 | 128) & fc->cart->CHRmask1[0]) << 10);
	  break;
	case 2:
	  fc->ppu->vnapage[0] = fc->ppu->vnapage[1] =
	      fc->ppu->vnapage[2] = fc->ppu->vnapage[3] =
		  fc->cart->CHRptr[0] +
		  (((nt1 | 128) & fc->cart->CHRmask1[0]) << 10);
	  break;
	case 3:
	  fc->ppu->vnapage[0] = fc->ppu->vnapage[1] =
	      fc->ppu->vnapage[2] = fc->ppu->vnapage[3] =
		  fc->cart->CHRptr[0] +
		  (((nt2 | 128) & fc->cart->CHRmask1[0]) << 10);
	  break;
      }
    } else {
      switch (mirr & 3) {
	case 0: fc->cart->setmirror(MI_V); break;
	case 1: fc->cart->setmirror(MI_H); break;
	case 2: fc->cart->setmirror(MI_0); break;
	case 3: fc->cart->setmirror(MI_1); break;
      }
    }
  }

  void Sync() {
    fc->cart->setchr2(0x0000, chr_reg[0]);
    fc->cart->setchr2(0x0800, chr_reg[1]);
    fc->cart->setchr2(0x1000, chr_reg[2]);
    fc->cart->setchr2(0x1800, chr_reg[3]);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg16r((fc->cart->PRGptr[1]) ? kogame : 0, 0x8000,
			      prg_reg);
    fc->cart->setprg16(0xC000, ~0);
  }

  DECLFR_RET M68Read(DECLFR_ARGS) {
    if (!(kogame & 8)) {
      count++;
      if (count == 1784) fc->cart->setprg16r(0, 0x8000, prg_reg);
    }
    return Cart::CartBR(DECLFR_FORWARD);
  }

  void M68WriteLo(DECLFW_ARGS) {
    if (!V) {
      count = 0;
      fc->cart->setprg16r((fc->cart->PRGptr[1]) ? kogame : 0, 0x8000,
				prg_reg);
    }
  }

  void M68WriteCHR(DECLFW_ARGS) {
    chr_reg[(A >> 12) & 3] = V;
    Sync();
  }

  void M68WriteNT1(DECLFW_ARGS) {
    nt1 = V;
    M68NTfix();
  }

  void M68WriteNT2(DECLFW_ARGS) {
    nt2 = V;
    M68NTfix();
  }

  void M68WriteMIR(DECLFW_ARGS) {
    mirr = V;
    M68NTfix();
  }

  void M68WriteROM(DECLFW_ARGS) {
    prg_reg = V & 7;
    kogame = ((V >> 3) & 1) ^ 1;
    Sync();
  }

  void Power() override {
    prg_reg = 0;
    kogame = 0;
    Sync();
    M68NTfix();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x8000, 0xBFFF, [](DECLFR_ARGS) {
      return ((Mapper68*)fc->fceu->cartiface)->M68Read(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0xC000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xBFFF, [](DECLFW_ARGS) {
      ((Mapper68*)fc->fceu->cartiface)->M68WriteCHR(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xC000, 0xCFFF, [](DECLFW_ARGS) {
      ((Mapper68*)fc->fceu->cartiface)->M68WriteNT1(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xD000, 0xDFFF, [](DECLFW_ARGS) {
      ((Mapper68*)fc->fceu->cartiface)->M68WriteNT2(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xE000, 0xEFFF, [](DECLFW_ARGS) {
      ((Mapper68*)fc->fceu->cartiface)->M68WriteMIR(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xF000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper68*)fc->fceu->cartiface)->M68WriteROM(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x6000, 0x6000, [](DECLFW_ARGS) {
      ((Mapper68*)fc->fceu->cartiface)->M68WriteLo(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x6001, 0x7FFF, Cart::CartBW);
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper68*)fc->fceu->cartiface)->Sync();
    ((Mapper68*)fc->fceu->cartiface)->M68NTfix();
  }

  Mapper68(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
    fc->state->AddExVec({{&nt1, 1, "NT10"},
	                 {&nt2, 1, "NT20"},
			 {&mirr, 1, "MIRR"},
			 {&prg_reg, 1, "PRG0"},
			 {&kogame, 1, "KGME"},
			 {&count, 4, "CNT0"},
			 {chr_reg, 4, "CHR0"}});
  }

};
}

CartInterface *Mapper68_Init(FC *fc, CartInfo *info) {
  return new Mapper68(fc, info);
}
