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

#include <string>

#include "mapinc.h"
#include "mmc3.h"
#include "../ines.h"

static constexpr int CHRRAMSIZE = 8192;

namespace {
struct BMCFK23C : public MMC3 {
  const bool is_BMCFK23CA = false;
  uint8 EXPREGS[8] = {};
  uint8 unromchr = 0;
  uint32 dipswitch = 0;

  // some games are wired differently, and this will need to be changed.
  // all the WXN games require prg_bonus = 1, and cah4e3's multicarts require
  // prg_bonus = 0
  // we'll populate this from a game database
  int prg_bonus = 0;
  int prg_mask = 0;

  // prg_bonus = 0
  // 4-in-1 (FK23C8021)[p1][!].nes
  // 4-in-1 (FK23C8033)[p1][!].nes
  // 4-in-1 (FK23C8043)[p1][!].nes
  // 4-in-1 (FK23Cxxxx, S-0210A PCB)[p1][!].nes

  // prg_bonus = 1
  //[m176]大富翁2-上海大亨.wxn.nes
  //[m176]宠物翡翠.fix.nes
  //[m176]格兰帝亚.wxn.nes
  //[m176]梦幻之星.wxn.nes
  //[m176]水浒神兽.fix.nes
  //[m176]西楚霸王.fix.nes
  //[m176]超级大富翁.wxn.nes
  //[m176]雄霸天下.wxn.nes

  // works as-is under virtuanes m176
  //[m176]三侠五义.wxn.nes
  //[m176]口袋金.fix.nes
  //[m176]爆笑三国.fix.nes

  // needs other tweaks
  //[m176]三国忠烈传.wxn.nes
  //[m176]破釜沉舟.fix.nes
  
  void CWrap(uint32 A, uint8 V) override {
    if (EXPREGS[0] & 0x40)
      fc->cart->setchr8(EXPREGS[2] | unromchr);
    else if (EXPREGS[0] & 0x20) {
      fc->cart->setchr1r(0x10, A, V);
    } else {
      uint16 base = (EXPREGS[2] & 0x7F) << 3;
      if (EXPREGS[3] & 2) {
	int cbase = (MMC3_cmd & 0x80) << 5;
	fc->cart->setchr1(A, V | base);
	fc->cart->setchr1(0x0000 ^ cbase, DRegBuf[0] | base);
	fc->cart->setchr1(0x0400 ^ cbase, EXPREGS[6] | base);
	fc->cart->setchr1(0x0800 ^ cbase, DRegBuf[1] | base);
	fc->cart->setchr1(0x0c00 ^ cbase, EXPREGS[7] | base);
      } else {
	fc->cart->setchr1(A, V | base);
      }
    }
  }


  // PRG wrapper
  void PWrap(uint32 A, uint8 V) override {
    // uint32 bank = (EXPREGS[1] & 0x1F);
    // uint32 hiblock = ((EXPREGS[0] & 8) << 4)|((EXPREGS[0] & 0x80) <<
    // 1)|(fc->unif->UNIFchrrama?((EXPREGS[2] & 0x40)<<3):0);
    // uint32 block = (EXPREGS[1] & 0x60) | hiblock;
    // uint32 extra = (EXPREGS[3] & 2);

    if ((EXPREGS[0] & 7) == 4) {
      fc->cart->setprg32(0x8000, EXPREGS[1] >> 1);
    } else if ((EXPREGS[0] & 7) == 3) {
      fc->cart->setprg16(0x8000, EXPREGS[1]);
      fc->cart->setprg16(0xC000, EXPREGS[1]);
    } else {
      if (EXPREGS[0] & 3) {
	uint32 blocksize = (6) - (EXPREGS[0] & 3);
	uint32 mask = (1 << blocksize) - 1;
	V &= mask;
	// V &= 63; //? is this a good idea?
	V |= (EXPREGS[1] << 1);
	fc->cart->setprg8(A, V);
      } else {
	fc->cart->setprg8(A, V & prg_mask);
      }

      if (EXPREGS[3] & 2) {
	fc->cart->setprg8(0xC000, EXPREGS[4]);
	fc->cart->setprg8(0xE000, EXPREGS[5]);
      }
    }
    fc->cart->setprg8r(0x10, 0x6000, A001B & 3);
  }

  // PRG handler ($8000-$FFFF)
  void BMCFK23CHiWrite(DECLFW_ARGS) {
    if (EXPREGS[0] & 0x40) {
      if (EXPREGS[0] & 0x30) {
	unromchr = 0;
      } else {
	unromchr = V & 3;
	FixMMC3CHR(MMC3_cmd);
      }
    } else {
      if ((A == 0x8001) && (EXPREGS[3] & 2 && MMC3_cmd & 8)) {
	EXPREGS[4 | (MMC3_cmd & 3)] = V;
	FixMMC3PRG(MMC3_cmd);
	FixMMC3CHR(MMC3_cmd);
      } else if (A < 0xC000) {
	if (fc->unif->UNIFchrrama) {
	  // hacky... strange behaviour, must be
	  // bit scramble due to pcb layout
	  // restrictions
	  // check if it not interfere with other dumps
	  if ((A == 0x8000) && (V == 0x46))
	    V = 0x47;
	  else if ((A == 0x8000) && (V == 0x47))
	    V = 0x46;
	}
	MMC3_CMDWrite(DECLFW_FORWARD);
	FixMMC3PRG(MMC3_cmd);
      } else {
	MMC3_IRQWrite(DECLFW_FORWARD);
      }
    }
  }

  // EXP handler ($5000-$5FFF)
  void BMCFK23CWrite(DECLFW_ARGS) {
    if (A & (1 << (dipswitch + 4))) {
      // printf("+ ");
      EXPREGS[A & 3] = V;

      bool remap = false;

      // sometimes writing to reg0 causes remappings to occur. we think the 2
      // signifies this.
      // if not, 0x24 is a value that is known to work
      // however, the low 4 bits are known to control the mapping
      // mode, so 0x20 is more likely to be the immediate remap flag
      remap |= ((EXPREGS[0] & 0xF0) == 0x20);

      // this is an actual mapping reg. i think reg0 controls what happens when
      // reg1 is written. anyway, we have to immediately remap these
      remap |= (A & 3) == 1;
      // this too.
      remap |= (A & 3) == 2;

      if (remap) {
	FixMMC3PRG(MMC3_cmd);
	FixMMC3CHR(MMC3_cmd);
      }
    }

    if (is_BMCFK23CA) {
      if (EXPREGS[3] & 2) {
	// hacky hacky! if someone wants extra banking, then
	// for sure doesn't want mode 4 for it! (allow to run A
	// version boards on normal mapper)
	EXPREGS[0] &= ~7;
      }
    }

    // printf("%04X = $%02X\n",A,V);
    // printf("%02X %02X %02X
    // %02X\n",EXPREGS[0],EXPREGS[1],EXPREGS[2],EXPREGS[3]);
  }

  void Reset() override {
    // NOT NECESSARY ANYMORE
    // this little hack makes sure that we try all the dip switch settings
    // eventually, if we reset enough
    // dipswitch++;
    // dipswitch&=7;
    // printf("BMCFK23C dipswitch set to %d\n",dipswitch);

    EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = EXPREGS[3] = 0;
    EXPREGS[4] = EXPREGS[5] = EXPREGS[6] = EXPREGS[7] = 0xFF;
    MMC3::Reset();
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  void Power() override {
    dipswitch = 0;
    MMC3::Power();
    EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = EXPREGS[3] = 0;
    EXPREGS[4] = EXPREGS[5] = EXPREGS[6] = EXPREGS[7] = 0xFF;
    // XXX Why is this called twice? -tom7
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x5000, 0x5fff, [](DECLFW_ARGS) {
      ((BMCFK23C*)fc->fceu->cartiface)->BMCFK23CWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((BMCFK23C*)fc->fceu->cartiface)->BMCFK23CHiWrite(DECLFW_FORWARD);
    });
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  BMCFK23C(FC *fc, CartInfo *info, bool is_ca) :
    MMC3(fc, info, 512, 256, 8, 0), is_BMCFK23CA(is_ca) {
    fc->state->AddExState(EXPREGS, 8, 0, "EXPR");
    fc->state->AddExState(&unromchr, 1, 0, "UCHR");
    fc->state->AddExState(&dipswitch, 1, 0, "DPSW");

    prg_bonus = 1;
    if (const std::string *val = fc->ines->MasterRomInfoParam("bonus")) {
      prg_bonus = atoi(val->c_str());
    }

    prg_mask = 0x7F >> (prg_bonus);
  }
};

struct BMCFK23CA : public BMCFK23C {
  uint8 *CHRRAM = nullptr;
  
  void Close() override {
    free(CHRRAM);
    CHRRAM = nullptr;
  }

  void Power() override {
    MMC3::Power();
    dipswitch = 0;
    EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = EXPREGS[3] = 0;
    EXPREGS[4] = EXPREGS[5] = EXPREGS[6] = EXPREGS[7] = 0xFF;
    fc->fceu->SetWriteHandler(0x5000, 0x5fff, [](DECLFW_ARGS) {
      ((BMCFK23CA*)fc->fceu->cartiface)->BMCFK23CWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((BMCFK23CA*)fc->fceu->cartiface)->BMCFK23CHiWrite(DECLFW_FORWARD);
    });
    FixMMC3PRG(MMC3_cmd);
    FixMMC3CHR(MMC3_cmd);
  }

  BMCFK23CA(FC *fc, CartInfo *info) : BMCFK23C(fc, info, true) {
    CHRRAM = (uint8 *)FCEU_gmalloc(CHRRAMSIZE);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRRAMSIZE, 1);
    fc->state->AddExState(CHRRAM, CHRRAMSIZE, 0, "CRAM");
  }
};
}

CartInterface *BMCFK23C_Init(FC *fc, CartInfo *info) {
  return new BMCFK23C(fc, info, false);
}

CartInterface *BMCFK23CA_Init(FC *fc, CartInfo *info) {
  return new BMCFK23CA(fc, info);
}
