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
 * 63in1 ghostbusters
 */

#include "mapinc.h"

static constexpr uint8 banks[4] = {0, 0, 1, 2};

static constexpr uint32 CHRROMSIZE = 8192;  // dummy CHRROM, VRAM disable

namespace {
struct Ghostbusters : public CartInterface {
  uint8 reg[2], bank;
  uint8 *CHRROM = nullptr;

  void Sync() {
    if (reg[0] & 0x20) {
      fc->cart->setprg16r(banks[bank], 0x8000, reg[0] & 0x1F);
      fc->cart->setprg16r(banks[bank], 0xC000, reg[0] & 0x1F);
    } else {
      fc->cart->setprg32r(banks[bank], 0x8000, (reg[0] >> 1) & 0x0F);
    }
    if (reg[1] & 2)
      fc->cart->setchr8r(0x10, 0);
    else
      fc->cart->setchr8(0);
    fc->cart->setmirror((reg[0] & 0x40) >> 6);
  }

  void BMCGhostbusters63in1Write(DECLFW_ARGS) {
    reg[A & 1] = V;
    bank = ((reg[0] & 0x80) >> 7) | ((reg[1] & 1) << 1);
    //	FCEU_printf("reg[0]=%02x, reg[1]=%02x, bank=%02x\n",reg[0],reg[1],bank);
    Sync();
  }

  DECLFR_RET BMCGhostbusters63in1Read(DECLFR_ARGS) {
    if (bank == 1)
      return fc->X->DB;
    else
      return Cart::CartBR(DECLFR_FORWARD);
  }

  void Power() override {
    reg[0] = reg[1] = 0;
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, [](DECLFR_ARGS) {
      return ((Ghostbusters*)fc->fceu->cartiface)->
	BMCGhostbusters63in1Read(DECLFR_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Ghostbusters*)fc->fceu->cartiface)->BMCGhostbusters63in1Write(DECLFW_FORWARD);
    });
  }

  void Reset() override {
    reg[0] = reg[1] = 0;
  }

  static void StateRestore(FC *fc, int version) {
    ((Ghostbusters *)fc->fceu->cartiface)->Sync();
  }

  void Close() override {
    free(CHRROM);
    CHRROM = nullptr;
  }

  Ghostbusters(FC *fc, CartInfo *info) : CartInterface(fc) {
    CHRROM = (uint8 *)FCEU_gmalloc(CHRROMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, CHRROM, CHRROMSIZE, 0);
    fc->state->AddExState(CHRROM, CHRROMSIZE, 0, "CROM");

    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{reg, 2, "REGS"}, {&bank, 1, "BANK"}});
  }
};
}

CartInterface *BMCGhostbusters63in1_Init(FC *fc, CartInfo *info) {
  return new Ghostbusters(fc, info);
}
