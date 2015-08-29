/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
 *  Copyright (C) 2011 FCEUX team
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
 * Bandai mappers
 *
 */

// Famicom Jump 2 should get transformed to m153
// All other games are not supporting EEPROM saving right now.
// We may need to distinguish between 16 and 159 in order to know the EEPROM
// configuration.
// Until then, we just return 0x00 from the EEPROM read

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct Bandai : public CartInterface {
  const bool is153 = false;
  
  uint8 reg[16] = {};
  uint8 IRQa = 0;
  int16 IRQCount = 0, IRQLatch = 0;

  uint8 *WRAM = nullptr;

  void BandaiIRQHook(int a) {
    if (IRQa) {
      IRQCount -= a;
      if (IRQCount < 0) {
	fc->X->IRQBegin(FCEU_IQEXT);
	IRQa = 0;
	IRQCount = -1;
      }
    }
  }

  void BandaiSync() {
    if (is153) {
      int base = (reg[0] & 1) << 4;
      fc->cart->setchr8(0);
      fc->cart->setprg16(0x8000, (reg[8] & 0x0F) | base);
      fc->cart->setprg16(0xC000, 0x0F | base);
    } else {
      for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, reg[i]);
      fc->cart->setprg16(0x8000, reg[8]);
      fc->cart->setprg16(0xC000, ~0);
    }
    switch (reg[9] & 3) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirror(MI_0); break;
      case 3: fc->cart->setmirror(MI_1); break;
    }
  }

  void BandaiWrite(DECLFW_ARGS) {
    A &= 0x0F;
    if (A < 0x0A) {
      reg[A & 0x0F] = V;
      BandaiSync();
    } else
      switch (A) {
	case 0x0A:
	  fc->X->IRQEnd(FCEU_IQEXT);
	  IRQa = V & 1;
	  IRQCount = IRQLatch;
	  break;
	case 0x0B:
	  IRQLatch &= 0xFF00;
	  IRQLatch |= V;
	  break;
	case 0x0C:
	  IRQLatch &= 0xFF;
	  IRQLatch |= V << 8;
	  break;
	case 0x0D: break;  // Serial EEPROM control port
      }
  }

  void Power() override {
    BandaiSync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0xFFFF, [](DECLFW_ARGS) {
      ((Bandai*)fc->fceu->cartiface)->BandaiWrite(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Bandai *)fc->fceu->cartiface)->BandaiSync();
  }

  Bandai(FC *fc, CartInfo *info, bool is153) : CartInterface(fc),
					       is153(is153) {
    fc->state->AddExVec({
      {reg, 16, "REGS"},
      {&IRQa, 1, "IRQA"},
      {&IRQCount, 2, "IRQC"},
      // need for Famicom Jump II - Saikyou no 7 Nin (J) [!]
      {&IRQLatch, 2, "IRQL"}});
  }
};

struct Mapper16 : public Bandai {
  Mapper16(FC *fc, CartInfo *info) : Bandai(fc, info, false) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper16 *)fc->fceu->cartiface)->BandaiIRQHook(a);
    };
    fc->fceu->GameStateRestore = StateRestore;
  }
};

struct Mapper153 : public Bandai {
  void Power() override {
    BandaiSync();
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper153*)fc->fceu->cartiface)->BandaiWrite(DECLFW_FORWARD);
    });
  }


  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }
  
  Mapper153(FC *fc, CartInfo *info) : Bandai(fc, info, true) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper153 *)fc->fceu->cartiface)->BandaiIRQHook(a);
    };

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE;
    }

    fc->fceu->GameStateRestore = StateRestore;
  }
};

// Datach Barcode Battler
struct Barcode : public Bandai {
  uint8 BarcodeData[256] = {};
  int BarcodeReadPos = 0;
  int BarcodeCycleCount = 0;
  uint32 BarcodeOut = 0;

  // Note: FCEUI_ functions are entry points from the UI.
  // This one is in an anonymous namespace and not callable.
  // To make the barcode game function, some work would be
  // needed here. -tom7
  int FCEUI_DatachSet(const uint8 *rcode) {
    static constexpr int prefix_parity_type[10][6] =
      {{0, 0, 0, 0, 0, 0}, {0, 0, 1, 0, 1, 1},
       {0, 0, 1, 1, 0, 1}, {0, 0, 1, 1, 1, 0},
       {0, 1, 0, 0, 1, 1}, {0, 1, 1, 0, 0, 1},
       {0, 1, 1, 1, 0, 0}, {0, 1, 0, 1, 0, 1},
       {0, 1, 0, 1, 1, 0}, {0, 1, 1, 0, 1, 0}};
    static constexpr int data_left_odd[10][7] =
      {{0, 0, 0, 1, 1, 0, 1}, {0, 0, 1, 1, 0, 0, 1},
       {0, 0, 1, 0, 0, 1, 1}, {0, 1, 1, 1, 1, 0, 1},
       {0, 1, 0, 0, 0, 1, 1}, {0, 1, 1, 0, 0, 0, 1},
       {0, 1, 0, 1, 1, 1, 1}, {0, 1, 1, 1, 0, 1, 1},
       {0, 1, 1, 0, 1, 1, 1}, {0, 0, 0, 1, 0, 1, 1}};
    static constexpr int data_left_even[10][7] =
      {{0, 1, 0, 0, 1, 1, 1}, {0, 1, 1, 0, 0, 1, 1},
       {0, 0, 1, 1, 0, 1, 1}, {0, 1, 0, 0, 0, 0, 1},
       {0, 0, 1, 1, 1, 0, 1}, {0, 1, 1, 1, 0, 0, 1},
       {0, 0, 0, 0, 1, 0, 1}, {0, 0, 1, 0, 0, 0, 1},
       {0, 0, 0, 1, 0, 0, 1}, {0, 0, 1, 0, 1, 1, 1}};
    static constexpr int data_right[10][7] =
      {{1, 1, 1, 0, 0, 1, 0}, {1, 1, 0, 0, 1, 1, 0},
       {1, 1, 0, 1, 1, 0, 0}, {1, 0, 0, 0, 0, 1, 0},
       {1, 0, 1, 1, 1, 0, 0}, {1, 0, 0, 1, 1, 1, 0},
       {1, 0, 1, 0, 0, 0, 0}, {1, 0, 0, 0, 1, 0, 0},
       {1, 0, 0, 1, 0, 0, 0}, {1, 1, 1, 0, 1, 0, 0}};
    uint8 code[13 + 1];
    uint32 tmp_p = 0;
    int i, j;
    int len;

    for (i = len = 0; i < 13; i++) {
      if (!rcode[i]) break;
      if ((code[i] = rcode[i] - '0') > 9) return 0;
      len++;
    }
    if (len != 13 && len != 12 && len != 8 && len != 7) return 0;

  #define BS(x)             \
    BarcodeData[tmp_p] = x; \
    tmp_p++

    for (j = 0; j < 32; j++) {
      BS(0x00);
    }

    /* Left guard bars */
    BS(1);
    BS(0);
    BS(1);

    if (len == 13 || len == 12) {
      uint32 csum;

      for (i = 0; i < 6; i++) {
	if (prefix_parity_type[code[0]][i]) {
	  for (j = 0; j < 7; j++) {
	    BS(data_left_even[code[i + 1]][j]);
	  }
	} else
	  for (j = 0; j < 7; j++) {
	    BS(data_left_odd[code[i + 1]][j]);
	  }
      }
	
      /* Center guard bars */
      BS(0);
      BS(1);
      BS(0);
      BS(1);
      BS(0);

      for (i = 7; i < 12; i++)
	for (j = 0; j < 7; j++) {
	  BS(data_right[code[i]][j]);
	}
      csum = 0;
      for (i = 0; i < 12; i++) csum += code[i] * ((i & 1) ? 3 : 1);
      csum = (10 - (csum % 10)) % 10;
      for (j = 0; j < 7; j++) {
	BS(data_right[csum][j]);
      }

    } else if (len == 8 || len == 7) {
      uint32 csum = 0;

      for (i = 0; i < 7; i++) csum += (i & 1) ? code[i] : (code[i] * 3);

      csum = (10 - (csum % 10)) % 10;

      for (i = 0; i < 4; i++)
	for (j = 0; j < 7; j++) {
	  BS(data_left_odd[code[i]][j]);
	}

      /* Center guard bars */
      BS(0);
      BS(1);
      BS(0);
      BS(1);
      BS(0);

      for (i = 4; i < 7; i++)
	for (j = 0; j < 7; j++) {
	  BS(data_right[code[i]][j]);
	}

      for (j = 0; j < 7; j++) {
	BS(data_right[csum][j]);
      }
    }

    /* Right guard bars */
    BS(1);
    BS(0);
    BS(1);

    for (j = 0; j < 32; j++) {
      BS(0x00);
    }

    BS(0xFF);

  #undef BS

    BarcodeReadPos = 0;
    BarcodeOut = 0x8;
    BarcodeCycleCount = 0;
    return 1;
  }

  void BarcodeIRQHook(int a) {
    BandaiIRQHook(a);

    BarcodeCycleCount += a;

    if (BarcodeCycleCount >= 1000) {
      BarcodeCycleCount -= 1000;
      if (BarcodeData[BarcodeReadPos] == 0xFF) {
	BarcodeOut = 0;
      } else {
	BarcodeOut = (BarcodeData[BarcodeReadPos] ^ 1) << 3;
	BarcodeReadPos++;
      }
    }
  }

  DECLFR_RET BarcodeRead(DECLFR_ARGS) {
    return BarcodeOut;
  }

  void Power() override {
    BarcodeData[0] = 0xFF;
    BarcodeReadPos = 0;
    BarcodeOut = 0;
    BarcodeCycleCount = 0;

    BandaiSync();

    fc->fceu->SetWriteHandler(0x6000, 0xFFFF, [](DECLFW_ARGS) {
      ((Barcode*)fc->fceu->cartiface)->BandaiWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, [](DECLFR_ARGS) {
      return ((Barcode*)fc->fceu->cartiface)->
	BarcodeRead(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  }

  Barcode(FC *fc, CartInfo *info) : Bandai(fc, info, false) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Barcode *)fc->fceu->cartiface)->BarcodeIRQHook(a);
    };

    fc->fceu->GameInfo->cspecial = SIS_DATACH;
    fc->fceu->GameStateRestore = StateRestore;
  }
};
}

CartInterface *Mapper16_Init(FC *fc, CartInfo *info) {
  return new Mapper16(fc, info);
}

CartInterface *Mapper153_Init(FC *fc, CartInfo *info) {
  return new Mapper153(fc, info);
}

CartInterface *Mapper157_Init(FC *fc, CartInfo *info) {
  return new Barcode(fc, info);
}
