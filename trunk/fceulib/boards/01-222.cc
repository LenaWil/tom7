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
 *
 * TXC mappers, originally much complex banksitching
 *
 * 01-22111-000 (05-00002-010) (132, 22211) - MGC-001 Qi Wang
 * 01-22110-000 (52S         )              - MGC-002 2-in-1 Gun
 * 01-22111-100 (02-00002-010) (173       ) - MGC-008 Mahjong Block
 *                             (079       ) - MGC-012 Poke Block
 * 01-22110-200 (05-00002-010) (036       ) - MGC-014 Strike Wolf
 * 01-22000-400 (05-00002-010) (036       ) - MGC-015 Policeman
 * 01-22017-000 (05-PT017-080) (189       ) - MGC-017 Thunder Warrior
 * 01-11160-000 (04-02310-000) (   , 11160) - MGC-023 6-in-1
 * 01-22270-000 (05-00002-010) (132, 22211) - MGC-xxx Creatom
 * 01-22200-400 (------------) (079       ) - ET.03   F-15 City War
 *                             (172       ) -         1991 Du Ma Racing
 *
 */

#include "mapinc.h"

namespace {
struct Mapper01_222 : public CartInterface {
  const bool is172, is173;
  uint8 reg[4] = {}, cmd = 0;
  vector<SFORMAT> StateRegs;

  void Sync() {
    fc->cart->setprg32(0x8000, (reg[2] >> 2) & 1);
    if (is172) {
      // 1991 DU MA Racing probably CHR bank sequence is WRONG, so it is
      // possible to rearrange CHR banks for normal UNIF board and
      // mapper 172 is unneccessary
      fc->cart->setchr8((((cmd ^ reg[2]) >> 3) & 2) |
			      (((cmd ^ reg[2]) >> 5) & 1));
    } else {
      fc->cart->setchr8(reg[2] & 3);
    }
  }

  void UNL22211WriteLo(DECLFW_ARGS) {
    //	FCEU_printf("bs %04x %02x\n",A,V);
    reg[A & 3] = V;
  }

  void UNL22211WriteHi(DECLFW_ARGS) {
    //	FCEU_printf("bs %04x %02x\n",A,V);
    cmd = V;
    Sync();
  }

  DECLFR_RET UNL22211ReadLo(DECLFR_ARGS) {
    return (reg[1] ^ reg[2]) | (is173 ? 0x01 : 0x40);
    //	if(reg[3])
    //		return reg[2];
    //	else
    //		return fc->X->DB;
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetReadHandler(0x4100, 0x4100, [](DECLFR_ARGS) {
      return ((Mapper01_222*)fc->fceu->cartiface)->
	UNL22211ReadLo(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x4100, 0x4103, [](DECLFW_ARGS) {
      return ((Mapper01_222*)fc->fceu->cartiface)->
	UNL22211WriteLo(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      return ((Mapper01_222*)fc->fceu->cartiface)->
	UNL22211WriteHi(DECLFW_FORWARD);
    });
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper01_222*)fc->fceu->cartiface)->Sync();
  }

  Mapper01_222(FC *fc, CartInfo *info,
	       bool is172, bool is173) : CartInterface(fc),
					 is172(is172), is173(is173) {
    // PERF probably doesn't need to stick around
    StateRegs = {{reg, 4, "REGS"}, {&cmd, 1, "CMD0"}};
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec(StateRegs);
  }
};
}

CartInterface *UNL22211_Init(FC *fc, CartInfo *info) {
  return new Mapper01_222(fc, info, 0, 0);
}

CartInterface *Mapper172_Init(FC *fc, CartInfo *info) {
  return new Mapper01_222(fc, info, 1, 0);
}

CartInterface *Mapper173_Init(FC *fc, CartInfo *info) {
  return new Mapper01_222(fc, info, 0, 1);
}
