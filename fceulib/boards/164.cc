/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel 2006 CaH4e3
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
 * Actually, all this may be the same mapper with different switcheable banking
 * modes, maybe it's just an subtypes
 * of the same one board with various modes locked just like SuperGame boards,
 * based on 215 mapper
 *
 */

#include "mapinc.h"


static constexpr int WRAMSIZE = 8192;

namespace {
struct Mapper164Base : public CartInterface {
  uint8 laststrobe = 0, trigger = 0;
  uint8 reg[8] = {};
  uint8 *WRAM = nullptr;

  virtual void WSync() {
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg32(0x8000, (reg[0] << 4) | (reg[1] & 0xF));
    fc->cart->setchr8(0);
  }
  
  static void StateRestore(FC *fc, int version) {
    ((Mapper164Base*)fc->fceu->cartiface)->WSync();
  }

  void Write(DECLFW_ARGS) {
    switch (A & 0x7300) {
      case 0x5100:
	reg[0] = V;
	WSync();
	break;
      case 0x5000:
	reg[1] = V;
	WSync();
	break;
      case 0x5300:
	reg[2] = V;
	break;
      case 0x5200:
	reg[3] = V;
	WSync();
	break;
    }
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  Mapper164Base(FC *fc, CartInfo *info) : CartInterface(fc) {
    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }

    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&laststrobe, 1, "STB0"}, {&trigger, 1, "TRG0"}, {reg, 8, "REGS"}});
  }
};

struct Mapper164 : public Mapper164Base {
  void Power() override {
    memset(reg, 0, 8);
    reg[1] = 0xFF;
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      ((Mapper164Base*)fc->fceu->cartiface)->Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    WSync();
  }
};

struct Mapper163 : public Mapper164Base {
  void Power() override {
    memset(reg, 0, 8);
    laststrobe = 1;
    fc->fceu->SetReadHandler(0x5000, 0x5FFF, [](DECLFR_ARGS) {
      return ((Mapper163*)fc->fceu->cartiface)->ReadLow(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      ((Mapper163*)fc->fceu->cartiface)->Write2(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    WSync();
  }

  DECLFR_RET ReadLow(DECLFR_ARGS) {
    switch (A & 0x7700) {
      case 0x5100:
	return reg[2] | reg[0] | reg[1] | (reg[3] ^ 0xff);
      case 0x5500:
	if (trigger) {
	  // Lei Dian Huang Bi Ka Qiu Chuan Shuo (NJ046)
	  // may broke other games
	  return reg[2] | reg[1];
	} else {
	  return 0;
	}
    }
    return 4;
  }
  
  void Write2(DECLFW_ARGS) {
    if (A == 0x5101) {
      if (laststrobe && !V) trigger ^= 1;
      laststrobe = V;
    } else if (A == 0x5100 && V == 6) {
      // damn thoose protected games
      fc->cart->setprg32(0x8000, 3);
    } else {
      switch (A & 0x7300) {
      case 0x5200:
        reg[0] = V;
        WSync();
        break;
      case 0x5000:
        reg[1] = V;
        WSync();
        if (!(reg[1] & 0x80) && (fc->ppu->scanline < 128))
          fc->cart->setchr8(0); /* fc->cart->setchr8(0); */
        break;
      case 0x5300: reg[2] = V; break;
      case 0x5100:
        reg[3] = V;
        WSync();
        break;
      }
    }
  }
  
  void M163HB() {
    if (reg[1] & 0x80) {
      if (fc->ppu->scanline == 239) {
	fc->cart->setchr4(0x0000, 0);
	fc->cart->setchr4(0x1000, 0);
      } else if (fc->ppu->scanline == 127) {
	fc->cart->setchr4(0x0000, 1);
	fc->cart->setchr4(0x1000, 1);
      }
      /*
	if(scanline>=127) {
	  // Hu Lu Jin Gang (NJ039) (Ch) [!] don't like it
	  setchr4(0x0000,1);
	  setchr4(0x1000,1);
	} else {
 	  setchr4(0x0000,0);
	  setchr4(0x1000,0);
	}
      */
    }
  }
  
  Mapper163(FC *fc, CartInfo *info) : Mapper164Base(fc, info) {
    fc->ppu->GameHBIRQHook = [](FC *fc) {
      ((Mapper163*)fc->fceu->cartiface)->M163HB();
    };
  }
};

struct UNLFS304 : public Mapper164Base {
  using Mapper164Base::Mapper164Base;

  void WSync() override {
    fc->cart->setchr8(0);
    fc->cart->setprg8r(0x10, 0x6000, 0);
    switch (reg[3] & 7) {
    case 0:
    case 2:
      fc->cart->setprg32(0x8000,
			 (reg[0] & 0xc) | (reg[1] & 2) |
			 ((reg[2] & 0xf) << 4));
      break;
    case 1:
    case 3:
      fc->cart->setprg32(0x8000, (reg[0] & 0xc) | (reg[2] & 0xf) << 4);
      break;
    case 4:
    case 6:
      fc->cart->setprg32(0x8000,
			 (reg[0] & 0xe) | ((reg[1] >> 1) & 1) |
			 ((reg[2] & 0xf) << 4));
      break;
    case 5:
    case 7:
      fc->cart->setprg32(0x8000, (reg[0] & 0xf) | ((reg[2] & 0xf) << 4));
      break;
    }
  }

  void Write3(DECLFW_ARGS) {
    reg[(A >> 8) & 3] = V;
    WSync();
  }
  
  void Power() override {
    reg[0] = 3;
    reg[1] = 0;
    reg[2] = 0;
    reg[3] = 7;
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      ((UNLFS304*)fc->fceu->cartiface)->Write3(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    WSync();
  }
};

}

CartInterface *Mapper164_Init(FC *fc, CartInfo *info) {
  return new Mapper164Base(fc, info);
}

CartInterface *Mapper163_Init(FC *fc, CartInfo *info) {
  return new Mapper163(fc, info);
}

CartInterface *UNLFS304_Init(FC *fc, CartInfo *info) {
  return new UNLFS304(fc, info);
}
