/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2007 CaH4e3
 *  Copyright (C) 2012 FCEUX team
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
#include "ines.h"

static constexpr uint32 WRAM176SIZE = 8192;

namespace {
struct Mapper176 : public CartInterface {
  uint8 prg[4] = {}, chr = 0, sbw = 0, we_sram = 0;
  uint8 *wram176 = nullptr;

  void Sync() {
    fc->cart->setprg8r(0x10, 0x6000, 0);
    fc->cart->setprg8(0x8000, prg[0]);
    fc->cart->setprg8(0xA000, prg[1]);
    fc->cart->setprg8(0xC000, prg[2]);
    fc->cart->setprg8(0xE000, prg[3]);

    fc->cart->setchr8(chr);
  }

  void M176Write_5001(DECLFW_ARGS) {
    // printf("%04X = $%02X\n", A, V);
    if (sbw) {
      prg[0] = V * 4;
      prg[1] = V * 4 + 1;
      prg[2] = V * 4 + 2;
      prg[3] = V * 4 + 3;
    }
    Sync();
  }

  void M176Write_5010(DECLFW_ARGS) {
    // printf("%04X = $%02X\n", A, V);
    if (V == 0x24) sbw = 1;
    Sync();
  }

  void M176Write_5011(DECLFW_ARGS) {
    V >>= 1;
    if (sbw) {
      prg[0] = V * 4;
      prg[1] = V * 4 + 1;
      prg[2] = V * 4 + 2;
      prg[3] = V * 4 + 3;
    }
    Sync();
  }

  void M176Write_5FF1(DECLFW_ARGS) {
    // printf("%04X = $%02X\n", A, V);
    V >>= 1;
    prg[0] = V * 4;
    prg[1] = V * 4 + 1;
    prg[2] = V * 4 + 2;
    prg[3] = V * 4 + 3;
    Sync();
  }

  void M176Write_5FF2(DECLFW_ARGS) {
    printf("%04X = $%02X\n", A, V);
    chr = V;
    Sync();
  }

  void M176Write_A001(DECLFW_ARGS) {
    we_sram = V & 0x03;
  }

  void M176Write_WriteSRAM(DECLFW_ARGS) {
    //	if (we_sram)
    Cart::CartBW(DECLFW_FORWARD);
  }

  void Power() override {
    fc->fceu->SetReadHandler(0x6000, 0x7fff, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7fff, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_WriteSRAM(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0xA001, 0xA001, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_A001(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5001, 0x5001, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_5001(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5010, 0x5010, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_5010(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5011, 0x5011, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_5011(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5ff1, 0x5ff1, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_5FF1(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0x5ff2, 0x5ff2, [](DECLFW_ARGS) {
      ((Mapper176*)fc->fceu->cartiface)->M176Write_5FF2(DECLFW_FORWARD);
    });

    we_sram = 0;
    sbw = 0;
    prg[0] = 0;
    prg[1] = 1;
    prg[2] = (fc->ines->ROM_size - 2) & 63;
    prg[3] = (fc->ines->ROM_size - 1) & 63;
    Sync();
  }

  void Close() override {
    free(wram176);
    wram176 = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper176*)fc->fceu->cartiface)->Sync();
  }

  Mapper176(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    wram176 = (uint8 *)FCEU_gmalloc(WRAM176SIZE);
    fc->cart->SetupCartPRGMapping(0x10, wram176, WRAM176SIZE, 1);
    fc->state->AddExState(wram176, WRAM176SIZE, 0, "WRAM");
    fc->state->AddExVec({
	{prg, 4, "PRG0"}, {&chr, 1, "CHR0"}, {&sbw, 1, "SBW0"}});
  }

};
}

CartInterface *Mapper176_Init(FC *fc, CartInfo *info) {
  return new Mapper176(fc, info);
}
