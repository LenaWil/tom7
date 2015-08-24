/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 CaH4e3
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

#define CARD_EXTERNAL_INSERED 0x80

namespace {
struct Mapper216 : public CartInterface {
  uint8 prg_reg = 0;
  uint8 chr_reg = 0;

  /*

  _GET_CHALLENGE:      .BYTE   0,$B4,  0,  0,$62

  _SELECT_FILE_1_0200: .BYTE   0,$A4,  1,  0,  2,  2,  0
  _SELECT_FILE_2_0201: .BYTE   0,$A4,  2,  0,  2,  2,  1
  _SELECT_FILE_2_0203: .BYTE   0,$A4,  2,  0,  2,  2,  3
  _SELECT_FILE_2_0204: .BYTE   0,$A4,  2,  0,  2,  2,  4
  _SELECT_FILE_2_0205: .BYTE   0,$A4,  2,  0,  2,  2,  5
  _SELECT_FILE_2_3F04: .BYTE   0,$A4,  2,  0,  2,$3F,  4
  _SELECT_FILE_2_4F00: .BYTE   0,$A4,  2,  0,  2,$4F,  0

  _READ_BINARY_5:      .BYTE   0,$B0,$85,  0,  2
  _READ_BINARY_6:      .BYTE   0,$B0,$86,  0,  4
  _READ_BINARY_6_0:    .BYTE   0,$B0,$86,  0,$18
  _READ_BINARY_0:      .BYTE   0,$B0,  0,  2,  3
  _READ_BINARY_0_0:    .BYTE   0,$B0,  0,  0,  4
  _READ_BINARY_0_1:    .BYTE   0,$B0,  0,  0, $C
  _READ_BINARY_0_2:    .BYTE   0,$B0,  0,  0,$10

  _UPDATE_BINARY:      .BYTE   0,$D6,  0,  0,  4
  _UPDATE_BINARY_0:    .BYTE   0,$D6,  0,  0,$10

  _GET_RESPONSE:       .BYTE $80,$C0,  2,$A1,  8
  _GET_RESPONSE_0:     .BYTE   0,$C0,  0,  0,  2
  _GET_RESPONSE_1:     .BYTE   0,$C0,  0,  0,  6
  _GET_RESPONSE_2:     .BYTE   0,$C0,  0,  0,  8
  _GET_RESPONSE_3:     .BYTE   0,$C0,  0,  0, $C
  _GET_RESPONSE_4:     .BYTE   0,$C0,  0,  0,$10

  byte_8C0B:           .BYTE $80,$30,  0,  2, $A,  0,  1
  byte_8C48:           .BYTE $80,$32,  0,  1,  4
  byte_8C89:           .BYTE $80,$34,  0,  0,  8,  0,  0
  byte_8D01:           .BYTE $80,$36,  0,  0, $C
  byte_8CA7:           .BYTE $80,$38,  0,  2,  4
  byte_8BEC:           .BYTE $80,$3A,  0,  3,  0

  byte_89A0:           .BYTE   0,$48,  0,  0,  6
  byte_8808:           .BYTE   0,$54,  0,  0,$1C
  byte_89BF:           .BYTE   0,$58,  0,  0,$1C

  _MANAGE_CHANNEL:     .BYTE   0,$70,  0,  0,  8
  byte_8CE5:           .BYTE   0,$74,  0,  0,$12
  byte_8C29:           .BYTE   0,$76,  0,  0,  8
  byte_8CC6:           .BYTE   0,$78,  0,  0,$12
  */

  void Sync() {
    fc->cart->setprg32(0x8000, prg_reg);
    fc->cart->setchr8(chr_reg);
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper216 *)fc->fceu->cartiface)->Sync();
  }

  void M216WriteHi(DECLFW_ARGS) {
    prg_reg = A & 1;
    chr_reg = (A & 0x0E) >> 1;
    Sync();
  }

  void M216Write5000(DECLFW_ARGS) {
    //  FCEU_printf("WRITE: %04x:%04x (PC=%02x
    //  cnt=%02x)\n",A,V,fc->X->PC,sim0bcnt);
  }

  DECLFR_RET M216Read5000(DECLFR_ARGS) {
    //    FCEU_printf("READ: %04x PC=%04x out=%02x byte=%02x cnt=%02x
    //    bit=%02x\n",A,fc->X->PC,sim0out,sim0byte,sim0bcnt,sim0bit);
    return 0;
  }

  void Power() override {
    prg_reg = 0;
    chr_reg = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((Mapper216*)fc->fceu->cartiface)->M216WriteHi(DECLFW_FORWARD);
      });
    fc->fceu->SetWriteHandler(0x5000, 0x5000, [](DECLFW_ARGS) {
	((Mapper216*)fc->fceu->cartiface)->M216Write5000(DECLFW_FORWARD);
      });
    fc->fceu->SetReadHandler(0x5000, 0x5000, [](DECLFR_ARGS) {
	return ((Mapper216*)fc->fceu->cartiface)->
	  M216Read5000(DECLFR_FORWARD);
      });
  }

  Mapper216(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&prg_reg, 1, "PREG"}, {&chr_reg, 1, "CREG"}});
  }
};
}
CartInterface *Mapper216_Init(FC *fc, CartInfo *info) {
  return new Mapper216(fc, info);
}
