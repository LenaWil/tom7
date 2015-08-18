/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
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
 * Logical bank layot 32 K BANK 0, 64K BANK 1, 32K ~0 hardwired, 8K is missing
 * need redump from MASKROM!
 * probably need refix mapper after hard dump
 *
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct UNLKS7030 : public CartInterface {
  uint8 reg0 = 0, reg1 = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setchr8(0);
    fc->cart->setprg32(0x8000, ~0);
    fc->cart->setprg4(0xb800, reg0);
    fc->cart->setprg4(0xc800, 8 + reg1);
  }

  // 6000 - 6BFF - RAM
  // 6C00 - 6FFF - BANK 1K REG1
  // 7000 - 7FFF - BANK 4K REG0

  void UNLKS7030RamWrite0(DECLFW_ARGS) {
    if ((A >= 0x6000) && A <= 0x6BFF) {
      WRAM[A - 0x6000] = V;
    } else if ((A >= 0x6C00) && A <= 0x6FFF) {
      Cart::CartBW(fc, 0xC800 + (A - 0x6C00), V);
    } else if ((A >= 0x7000) && A <= 0x7FFF) {
      Cart::CartBW(fc, 0xB800 + (A - 0x7000), V);
    }
  }

  DECLFR_RET UNLKS7030RamRead0(DECLFR_ARGS) {
    if ((A >= 0x6000) && A <= 0x6BFF) {
      return WRAM[A - 0x6000];
    } else if ((A >= 0x6C00) && A <= 0x6FFF) {
      return Cart::CartBR(fc, 0xC800 + (A - 0x6C00));
    } else if ((A >= 0x7000) && A <= 0x7FFF) {
      return Cart::CartBR(fc, 0xB800 + (A - 0x7000));
    }
    return 0;
  }

  // B800 - BFFF - RAM
  // C000 - CBFF - BANK 3K
  // CC00 - D7FF - RAM

  void UNLKS7030RamWrite1(DECLFW_ARGS) {
    if ((A >= 0xB800) && A <= 0xBFFF) {
      WRAM[0x0C00 + (A - 0xB800)] = V;
    } else if ((A >= 0xC000) && A <= 0xCBFF) {
      Cart::CartBW(fc, 0xCC00 + (A - 0xC000), V);
    } else if ((A >= 0xCC00) && A <= 0xD7FF) {
      WRAM[0x1400 + (A - 0xCC00)] = V;
    }
  }

  DECLFR_RET UNLKS7030RamRead1(DECLFR_ARGS) {
    if ((A >= 0xB800) && A <= 0xBFFF) {
      return WRAM[0x0C00 + (A - 0xB800)];
    } else if ((A >= 0xC000) && A <= 0xCBFF) {
      return Cart::CartBR(fc, 0xCC00 + (A - 0xC000));
    } else if ((A >= 0xCC00) && A <= 0xD7FF) {
      return WRAM[0x1400 + (A - 0xCC00)];
    }
    return 0;
  }

  void UNLKS7030Write0(DECLFW_ARGS) {
    reg0 = A & 7;
    Sync();
  }

  void UNLKS7030Write1(DECLFW_ARGS) {
    reg1 = A & 15;
    Sync();
  }

  void Power() override {
    reg0 = reg1 = ~0;
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, [](DECLFR_ARGS) {
      return ((UNLKS7030*)fc->fceu->cartiface)->
	UNLKS7030RamRead0(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, [](DECLFW_ARGS) {
      ((UNLKS7030*)fc->fceu->cartiface)->UNLKS7030RamWrite0(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0x8FFF, [](DECLFW_ARGS) {
      ((UNLKS7030*)fc->fceu->cartiface)->UNLKS7030Write0(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x9000, 0x9FFF, [](DECLFW_ARGS) {
      ((UNLKS7030*)fc->fceu->cartiface)->UNLKS7030Write1(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0xB800, 0xD7FF, [](DECLFR_ARGS) {
      return ((UNLKS7030*)fc->fceu->cartiface)->
	UNLKS7030RamRead1(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xB800, 0xD7FF, [](DECLFW_ARGS) {
      ((UNLKS7030*)fc->fceu->cartiface)->UNLKS7030RamWrite1(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLKS7030*)fc->fceu->cartiface)->Sync();
  }

  UNLKS7030(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({{&reg0, 1, "REG0"}, {&reg1, 1, "REG1"}});
  }

};
}

CartInterface *UNLKS7030_Init(FC *fc, CartInfo *info) {
  return new UNLKS7030(fc, info);
}
