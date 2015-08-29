/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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
struct Sachen : public CartInterface {
  uint8 cmd = 0, dip = 0;
  uint8 latch[8] = {};

  void S74LS374NSynco() {
    fc->cart->setprg32(0x8000, latch[0]);
    fc->cart->setchr8(latch[1] | latch[3] | latch[4]);
    S74LS374MSync(latch[2]);
  }

  static void S74LS374NRestore(FC *fc, int version) {
    ((Sachen *)fc->fceu->cartiface)->S74LS374NSynco();
  }
  
  void S74LS374MSync(uint8 mirr) {
    switch (mirr & 3) {
      case 0: fc->cart->setmirror(MI_V); break;
      case 1: fc->cart->setmirror(MI_H); break;
      case 2: fc->cart->setmirrorw(0, 1, 1, 1); break;
      case 3: fc->cart->setmirror(MI_0); break;
    }
  }

  Sachen(FC *fc, CartInfo *info) : CartInterface(fc) {
    
  }
};

struct S74LS374N : public Sachen {
  DECLFR_RET S74LS374NRead(DECLFR_ARGS) {
    uint8 ret;
    if ((A & 0x4100) == 0x4100)
      //	  ret=(fc->X->DB&0xC0)|((~cmd)&0x3F);
      ret = ((~cmd) & 0x3F) ^ dip;
    else
      ret = fc->X->DB;
    return ret;
  }

  void S74LS374NWrite(DECLFW_ARGS) {
    A &= 0x4101;
    if (A == 0x4100)
      cmd = V & 7;
    else {
      switch (cmd) {
	case 2:
	  latch[0] = V & 1;
	  latch[3] = (V & 1) << 3;
	  break;
	case 4: latch[4] = (V & 1) << 2; break;
	case 5: latch[0] = V & 7; break;
	case 6: latch[1] = V & 3; break;
	case 7: latch[2] = V >> 1; break;
      }
      S74LS374NSynco();
    }
  }
  
  void Reset() override {
    dip ^= 1;
    latch[0] = latch[1] = latch[2] = latch[3] = latch[4] = 0;
    S74LS374NSynco();
  }

  void Power() override {
    dip = 0;
    latch[0] = latch[1] = latch[2] = latch[3] = latch[4] = 0;
    S74LS374NSynco();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4100, 0x7FFF, [](DECLFW_ARGS) {
      ((S74LS374N*)fc->fceu->cartiface)->S74LS374NWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x4100, 0x5fff, [](DECLFR_ARGS) {
      return ((S74LS374N*)fc->fceu->cartiface)->
	S74LS374NRead(DECLFR_FORWARD);
    });
  }
  
  S74LS374N(FC *fc, CartInfo *info) : Sachen(fc, info) {
    fc->fceu->GameStateRestore = S74LS374NRestore;
    fc->state->AddExState(latch, 5, 0, "LATC");
    fc->state->AddExState(&cmd, 1, 0, "CMD0");
    fc->state->AddExState(&dip, 1, 0, "DIP0");
  }
};
  
struct S74LS374NA : public Sachen {
  void S74LS374NASynco() {
    fc->cart->setprg32(0x8000, latch[0]);
    fc->cart->setchr8(latch[1]);
    S74LS374MSync(latch[2]);
  }

  void S74LS374NAWrite(DECLFW_ARGS) {
    A &= 0x4101;
    if (A == 0x4100)
      cmd = V & 7;
    else {
      switch (cmd) {
	case 0:
	  latch[0] = 0;
	  latch[1] = 3;
	  break;
	case 2: latch[3] = (V & 1) << 3; break;
	case 4: latch[1] = (latch[1] & 6) | (V & 3); break;
	case 5: latch[0] = V & 1; break;
	case 6: latch[1] = (latch[1] & 1) | latch[3] | ((V & 3) << 1); break;
	case 7: latch[2] = V & 1; break;
      }
      S74LS374NASynco();
    }
  }

  void Power() override {
    latch[0] = latch[2] = latch[3] = latch[4] = 0;
    latch[1] = 3;
    S74LS374NASynco();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4100, 0x7FFF, [](DECLFW_ARGS) {
      ((S74LS374NA*)fc->fceu->cartiface)->S74LS374NAWrite(DECLFW_FORWARD);
    });
  }

  S74LS374NA(FC *fc, CartInfo *info) : Sachen(fc, info) {
    // Note: This calls the "374N" version of restore, despite
    // having its own "374NA" Synco. Bug? -tom7
    fc->fceu->GameStateRestore = S74LS374NRestore;
    fc->state->AddExState(latch, 5, 0, "LATC");
    fc->state->AddExState(&cmd, 1, 0, "CMD0");
  }
};
  

struct S8259 : public Sachen {
  const int type = 0;
  void S8259Synco() {
    fc->cart->setprg32(0x8000, latch[5] & 7);

    if (!fc->unif->UNIFchrrama) {
      // No CHR RAM?  Then BS'ing is ok.
      for (int x = 0; x < 4; x++) {
	int bank;
	if (latch[7] & 1)
	  bank = (latch[0] & 0x7) | ((latch[4] & 7) << 3);
	else
	  bank = (latch[x] & 0x7) | ((latch[4] & 7) << 3);
	switch (type) {
	  case 00:
	    bank = (bank << 1) | (x & 1);
	    fc->cart->setchr2(0x800 * x, bank);
	    break;
	  case 01: fc->cart->setchr2(0x800 * x, bank); break;
	  case 02:
	    bank = (bank << 2) | (x & 3);
	    fc->cart->setchr2(0x800 * x, bank);
	    break;
	  case 03:
	    bank = latch[x] & 7;
	    switch (x & 3) {
	      case 01: bank |= (latch[4] & 1) << 4; break;
	      case 02: bank |= (latch[4] & 2) << 3; break;
	      case 03:
		bank |= ((latch[4] & 4) << 2) | ((latch[6] & 1) << 3);
		break;
	    }
	    fc->cart->setchr1(0x400 * x, bank);
	    fc->cart->setchr4(0x1000, ~0);
	    break;
	}
      }
    }
    if (!(latch[7] & 1))
      S74LS374MSync(latch[7] >> 1);
    else
      fc->cart->setmirror(MI_V);
  }

  void S8259Write(DECLFW_ARGS) {
    A &= 0x4101;
    if (A == 0x4100)
      cmd = V;
    else {
      latch[cmd & 7] = V;
      S8259Synco();
    }
  }

  // was 8259Reset, but assigned to Power
  void Power() override {
    cmd = 0;

    for (int x = 0; x < 8; x++) latch[x] = 0;
    fc->cart->setchr8(0);

    S8259Synco();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4100, 0x7FFF, [](DECLFW_ARGS) {
      ((S8259*)fc->fceu->cartiface)->S8259Write(DECLFW_FORWARD);
    });
  }

  static void S8259Restore(FC *fc, int version) {
    ((S8259 *)fc->fceu->cartiface)->S8259Synco();
  }
  
  S8259(FC *fc, CartInfo *info, int type) : Sachen(fc, info), type(type) {
    fc->fceu->GameStateRestore = S8259Restore;
    fc->state->AddExState(latch, 8, 0, "LATC");
    fc->state->AddExState(&cmd, 1, 0, "CMD0");
  }
};

struct SA : public Sachen {
  const bool is_sad = false;
  
  virtual void WSync() {}

  void SAWrite(DECLFW_ARGS) {
    if (A & 0x100) {
      latch[0] = V;
      WSync();
    }
  }
  
  void SADWrite(DECLFW_ARGS) {
    latch[0] = V;
    WSync();
  }

  void Power() override {
    if (is_sad) {
      latch[0] = 0;
      WSync();
      fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
      fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((SA*)fc->fceu->cartiface)->SADWrite(DECLFW_FORWARD);
      });
    } else {
      latch[0] = 0;
      WSync();
      fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
      fc->fceu->SetWriteHandler(0x4100, 0x5FFF, [](DECLFW_ARGS) {
	((SA*)fc->fceu->cartiface)->SAWrite(DECLFW_FORWARD);
      });
    }
  }

  static void SARestore(FC *fc, int version) {
    ((SA *)fc->fceu->cartiface)->WSync();
  }

  SA(FC *fc, CartInfo *info, bool is_sad) : Sachen(fc, info), is_sad(is_sad) {
    fc->fceu->GameStateRestore = SARestore;
    fc->state->AddExState(&latch[0], 1, 0, "LATC");
  }
};
  
struct SA0161M : public SA {
  using SA::SA;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch[0] >> 3) & 1);
    fc->cart->setchr8(latch[0] & 7);
  }
};

struct SA72007 : public SA {
  using SA::SA;
  void WSync() override {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(latch[0] >> 7);
  }
};

struct SA009 : public SA {
  using SA::SA;
  void WSync() override {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(latch[0] & 1);
  }
};

struct SA72008 : public SA {
  using SA::SA;
  void WSync() override {
    fc->cart->setprg32(0x8000, (latch[0] >> 2) & 1);
    fc->cart->setchr8(latch[0] & 3);
  }
};

// -----------------------------------------------

struct TCU01 : public Sachen {
  void TCU01Synco() {
    fc->cart->setprg32(0x8000,
		       ((latch[0] & 0x80) >> 6) | ((latch[0] >> 2) & 1));
    fc->cart->setchr8((latch[0] >> 3) & 0xF);
  }

  void TCU01Write(DECLFW_ARGS) {
    if ((A & 0x103) == 0x102) {
      latch[0] = V;
      TCU01Synco();
    }
  }

  void Power() override {
    latch[0] = 0;
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x4100, 0xFFFF, [](DECLFW_ARGS) {
      ((TCU01*)fc->fceu->cartiface)->TCU01Write(DECLFW_FORWARD);
    });
    TCU01Synco();
  }

  static void TCU01Restore(FC *fc, int version) {
    ((TCU01 *)fc->fceu->cartiface)->TCU01Synco();
  }

  TCU01(FC *fc, CartInfo *info) : Sachen(fc, info) {
    fc->fceu->GameStateRestore = TCU01Restore;
    fc->state->AddExState(&latch[0], 1, 0, "LATC");
  }
};

//-----------------------------------------------

struct TCU02 : public Sachen {
  void TCU02Synco() {
    fc->cart->setprg32(0x8000, 0);
    fc->cart->setchr8(latch[0] & 3);
  }

  void TCU02Write(DECLFW_ARGS) {
    if ((A & 0x103) == 0x102) {
      latch[0] = V + 3;
      TCU02Synco();
    }
  }

  DECLFR_RET TCU02Read(DECLFR_ARGS) {
    return (latch[0] & 0x3F) | (fc->X->DB & 0xC0);
  }

  void Power() override {
    latch[0] = 0;
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x4100, 0x4100, [](DECLFR_ARGS) {
      return ((TCU02*)fc->fceu->cartiface)->TCU02Read(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4100, 0xFFFF, [](DECLFW_ARGS) {
      ((TCU02*)fc->fceu->cartiface)->TCU02Write(DECLFW_FORWARD);
    });
    TCU02Synco();
  }

  static void TCU02Restore(FC *fc, int version) {
    ((TCU02 *)fc->fceu->cartiface)->TCU02Synco();
  }

  TCU02(FC *fc, CartInfo *info) : Sachen(fc, info) {
    fc->fceu->GameStateRestore = TCU02Restore;
    fc->state->AddExState(&latch[0], 1, 0, "LATC");
  }
};

// ---------------------------------------------

struct TCA01 : public Sachen {
  DECLFR_RET TCA01Read(DECLFR_ARGS) {
    uint8 ret;
    if ((A & 0x4100) == 0x4100)
      ret = (fc->X->DB & 0xC0) | ((~A) & 0x3F);
    else
      ret = fc->X->DB;
    return ret;
  }

  void Power() override {
    fc->cart->setprg16(0x8000, 0);
    fc->cart->setprg16(0xC000, 1);
    fc->cart->setchr8(0);
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x4100, 0x5FFF, [](DECLFR_ARGS) {
      return ((TCA01*)fc->fceu->cartiface)->
	TCA01Read(DECLFR_FORWARD);
    });
  }

  using Sachen::Sachen;
};

}

CartInterface *S74LS374N_Init(FC *fc, CartInfo *info) {
  return new S74LS374N(fc, info);
}

CartInterface *S74LS374NA_Init(FC *fc, CartInfo *info) {
  return new S74LS374NA(fc, info);
}


// Kevin's Horton 141 mapper
CartInterface *S8259A_Init(FC *fc, CartInfo *info) {
  return new S8259(fc, info, 0);
}

// Kevin's Horton 138 mapper
CartInterface *S8259B_Init(FC *fc, CartInfo *info) {
  return new S8259(fc, info, 1);
}

// Kevin's Horton 139 mapper
CartInterface *S8259C_Init(FC *fc, CartInfo *info) {
  return new S8259(fc, info, 2);
}

// Kevin's Horton 137 mapper
CartInterface *S8259D_Init(FC *fc, CartInfo *info) {
  return new S8259(fc, info, 3);
}


CartInterface *SA0161M_Init(FC *fc, CartInfo *info) {
  return new SA0161M(fc, info, false);
}

CartInterface *SA72007_Init(FC *fc, CartInfo *info) {
  return new SA72007(fc, info, false);
}

CartInterface *SA72008_Init(FC *fc, CartInfo *info) {
  return new SA72008(fc, info, false);
}

CartInterface *SA009_Init(FC *fc, CartInfo *info) {
  return new SA009(fc, info, false);
}

CartInterface *SA0036_Init(FC *fc, CartInfo *info) {
  return new SA72007(fc, info, true);
}

CartInterface *SA0037_Init(FC *fc, CartInfo *info) {
  return new SA0161M(fc, info, true);
}


CartInterface *TCU01_Init(FC *fc, CartInfo *info) {
  return new TCU01(fc, info);
}

CartInterface *TCU02_Init(FC *fc, CartInfo *info) {
  return new TCU02(fc, info);
}

CartInterface *TCA01_Init(FC *fc, CartInfo *info) {
  return new TCA01(fc, info);
}
