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
struct YokoBase : public CartInterface {
  uint8 mode = 0, bank = 0, reg[11] = {}, low[4] = {}, dip = 0, IRQa = 0;
  int32 IRQCount = 0;
  uint8 *WRAM = nullptr;

  uint8 is2kbank = 0;
  uint8 isnot2kbank = 0;

  void UNLYOKOSync() {
    fc->cart->setmirror((mode & 1) ^ 1);
    fc->cart->setchr2(0x0000, reg[3]);
    fc->cart->setchr2(0x0800, reg[4]);
    fc->cart->setchr2(0x1000, reg[5]);
    fc->cart->setchr2(0x1800, reg[6]);
    if (mode & 0x10) {
      const uint32 base = (bank & 8) << 1;
      fc->cart->setprg8(0x8000, (reg[0] & 0x0f) | base);
      fc->cart->setprg8(0xA000, (reg[1] & 0x0f) | base);
      fc->cart->setprg8(0xC000, (reg[2] & 0x0f) | base);
      fc->cart->setprg8(0xE000, 0x0f | base);
    } else {
      if (mode & 8) {
	fc->cart->setprg32(0x8000, bank >> 1);
      } else {
	fc->cart->setprg16(0x8000, bank);
	fc->cart->setprg16(0xC000, ~0);
      }
    }
  }

  void UNLYOKOWrite(DECLFW_ARGS) {
    switch (A & 0x8C17) {
      case 0x8000:
	bank = V;
	UNLYOKOSync();
	break;
      case 0x8400:
	mode = V;
	UNLYOKOSync();
	break;
      case 0x8800:
	IRQCount &= 0xFF00;
	IRQCount |= V;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0x8801:
	IRQa = mode & 0x80;
	IRQCount &= 0xFF;
	IRQCount |= V << 8;
	break;
      case 0x8c00:
	reg[0] = V;
	UNLYOKOSync();
	break;
      case 0x8c01:
	reg[1] = V;
	UNLYOKOSync();
	break;
      case 0x8c02:
	reg[2] = V;
	UNLYOKOSync();
	break;
      case 0x8c10:
	reg[3] = V;
	UNLYOKOSync();
	break;
      case 0x8c11:
	reg[4] = V;
	UNLYOKOSync();
	break;
      case 0x8c16:
	reg[5] = V;
	UNLYOKOSync();
	break;
      case 0x8c17:
	reg[6] = V;
	UNLYOKOSync();
	break;
    }
  }

  DECLFR_RET UNLYOKOReadDip(DECLFR_ARGS) {
    return (fc->X->DB & 0xFC) | dip;
  }

  DECLFR_RET UNLYOKOReadLow(DECLFR_ARGS) {
    return low[A & 3];
  }

  void UNLYOKOWriteLow(DECLFW_ARGS) {
    low[A & 3] = V;
  }

  void UNLYOKOIRQHook(int a) {
    if (IRQa) {
      IRQCount -= a;
      if (IRQCount < 0) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
	IRQCount = 0xFFFF;
      }
    }
  }

  YokoBase(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((YokoBase *)fc->fceu->cartiface)->UNLYOKOIRQHook(a);
    };
    fc->state->AddExVec({
      {&mode, 1, "MODE"},
      {&bank, 1, "BANK"},
      {&IRQCount, 4, "IRQC"},
      {&IRQa, 1, "IRQA"},
      {reg, 11, "REGS"},
      {low, 4, "LOWR"},
      {&is2kbank, 1, "IS2K"},
      {&isnot2kbank, 1, "NT2K"},
    });
  }
};

struct Mapper83 : public YokoBase {
  void M83Write(DECLFW_ARGS) {
    switch (A) {
      case 0x8000: is2kbank = 1;
      case 0xB000:  // Dragon Ball Z Party [p1] BMC
      case 0xB0FF:  // Dragon Ball Z Party [p1] BMC
      case 0xB1FF:
	bank = V;
	mode |= 0x40;
	M83Sync();
	break;  // Dragon Ball Z Party [p1] BMC
      case 0x8100:
	mode = V | (mode & 0x40);
	M83Sync();
	break;
      case 0x8200:
	IRQCount &= 0xFF00;
	IRQCount |= V;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0x8201:
	IRQa = mode & 0x80;
	IRQCount &= 0xFF;
	IRQCount |= V << 8;
	break;
      case 0x8300:
	reg[8] = V;
	mode &= 0xBF;
	M83Sync();
	break;
      case 0x8301:
	reg[9] = V;
	mode &= 0xBF;
	M83Sync();
	break;
      case 0x8302:
	reg[10] = V;
	mode &= 0xBF;
	M83Sync();
	break;
      case 0x8310:
	reg[0] = V;
	M83Sync();
	break;
      case 0x8311:
	reg[1] = V;
	M83Sync();
	break;
      case 0x8312:
	reg[2] = V;
	isnot2kbank = 1;
	M83Sync();
	break;
      case 0x8313:
	reg[3] = V;
	isnot2kbank = 1;
	M83Sync();
	break;
      case 0x8314:
	reg[4] = V;
	isnot2kbank = 1;
	M83Sync();
	break;
      case 0x8315:
	reg[5] = V;
	isnot2kbank = 1;
	M83Sync();
	break;
      case 0x8316:
	reg[6] = V;
	M83Sync();
	break;
      case 0x8317:
	reg[7] = V;
	M83Sync();
	break;
    }
  }

  void Power() override {
    is2kbank = 0;
    isnot2kbank = 0;
    mode = bank = 0;
    dip = 0;
    M83Sync();
    fc->fceu->SetReadHandler(0x5000, 0x5000, [](DECLFR_ARGS) {
      return ((Mapper83*)fc->fceu->cartiface)->
	UNLYOKOReadDip(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0x5100, 0x5103, [](DECLFR_ARGS) {
      return ((Mapper83*)fc->fceu->cartiface)->
	UNLYOKOReadLow(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5100, 0x5103, [](DECLFW_ARGS) {
      ((Mapper83*)fc->fceu->cartiface)->UNLYOKOWriteLow(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
    // Pirate Dragon Ball Z Party [p1] used if for saves instead of
    // serial EEPROM
    fc->fceu->SetWriteHandler(0x6000, 0x7fff, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xffff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
      ((Mapper83*)fc->fceu->cartiface)->M83Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    dip ^= 1;
    M83Sync();
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }
  
  void M83Sync() {
    // check if it is truth
    switch (mode & 3) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_0); break;
      case 3: fc->cart->setmirror(MI_1); break;
    }
    if (is2kbank && !isnot2kbank) {
      fc->cart->setchr2(0x0000, reg[0]);
      fc->cart->setchr2(0x0800, reg[1]);
      fc->cart->setchr2(0x1000, reg[6]);
      fc->cart->setchr2(0x1800, reg[7]);
    } else {
      for (int x = 0; x < 8; x++)
	fc->cart->setchr1(x << 10, reg[x] | ((bank & 0x30) << 4));
    }
    fc->cart->setprg8r(0x10, 0x6000, 0);
    if (mode & 0x40) {
      fc->cart->setprg16(0x8000, (bank & 0x3F));  // DBZ Party [p1]
      fc->cart->setprg16(0xC000, (bank & 0x30) | 0xF);
    } else {
      fc->cart->setprg8(0x8000, reg[8]);
      fc->cart->setprg8(0xA000, reg[9]);
      fc->cart->setprg8(0xC000, reg[10]);
      fc->cart->setprg8(0xE000, ~0);
    }
  }
 
  static void M83StateRestore(FC *fc, int version) {
    ((Mapper83 *)fc->fceu->cartiface)->M83Sync();
  }

  Mapper83(FC *fc, CartInfo *info) : YokoBase(fc, info) {
    fc->fceu->GameStateRestore = M83StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");
  }
};

struct Yoko : public YokoBase {
  void Power() override {
    mode = bank = 0;
    dip = 3;
    UNLYOKOSync();
    fc->fceu->SetReadHandler(0x5000, 0x53FF, [](DECLFR_ARGS) {
      return ((Yoko *)fc->fceu->cartiface)->
	UNLYOKOReadDip(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0x5400, 0x5FFF, [](DECLFR_ARGS) {
      return ((Yoko*)fc->fceu->cartiface)->
	UNLYOKOReadLow(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5400, 0x5FFF, [](DECLFW_ARGS) {
      ((Yoko*)fc->fceu->cartiface)->UNLYOKOWriteLow(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Yoko*)fc->fceu->cartiface)->UNLYOKOWrite(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    dip = (dip + 1) & 3;
    mode = bank = 0;
    UNLYOKOSync();
  }
  
  static void UNLYOKOStateRestore(FC *fc, int version) {
    ((Yoko *)fc->fceu->cartiface)->UNLYOKOSync();
  }

  Yoko(FC *fc, CartInfo *info) : YokoBase(fc, info) {
    fc->fceu->GameStateRestore = UNLYOKOStateRestore;    
  }
  
};
}
  
CartInterface *UNLYOKO_Init(FC *fc, CartInfo *info) {
  return new Yoko(fc, info);
}

CartInterface *Mapper83_Init(FC *fc, CartInfo *info) {
  return new Mapper83(fc, info);
}
