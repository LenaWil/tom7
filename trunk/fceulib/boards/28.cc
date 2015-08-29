/*
    Copyright (C) 2012 FCEUX team

    This file is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This file is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the this software.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "mapinc.h"

// http://wiki.nesdev.com/w/index.php/INES_Mapper_028

namespace {
struct Mapper28 : public CartInterface {
  // config
  int prg_mask_16k = 0;

  // state
  uint8 reg = 0;
  uint8 chr = 0;
  uint8 prg = 0;
  uint8 mode = 0;
  uint8 outer = 0;

  void SyncMirror() {
    switch (mode & 3) {
      case 0: fc->cart->setmirror(MI_0); break;
      case 1: fc->cart->setmirror(MI_1); break;
      case 2: fc->cart->setmirror(MI_V); break;
      case 3: fc->cart->setmirror(MI_H); break;
    }
  }

  void Mirror(uint8 value) {
    if ((mode & 2) == 0) {
      mode &= 0xfe;
      mode |= value >> 4 & 1;
    }
    SyncMirror();
  }

  void Sync() {
    // Note: Compiler thinks maybe these can be uninitialized; maybe it
    // doesn't understand that all the cases are covered below after the &,
    // or maybe something is missing. -tom7
    int prglo = 0;
    int prghi = 0;

    int outb = outer << 1;
    // this can probably be rolled up, but i have no motivation to do so
    // until it's been tested
    switch (mode & 0x3c) {
      // 32K modes
      case 0x00:
      case 0x04:
	prglo = outb;
	prghi = outb | 1;
	break;
      case 0x10:
      case 0x14:
	prglo = (outb & ~2) | (prg << 1 & 2);
	prghi = (outb & ~2) | (prg << 1 & 2) | 1;
	break;
      case 0x20:
      case 0x24:
	prglo = (outb & ~6) | (prg << 1 & 6);
	prghi = (outb & ~6) | (prg << 1 & 6) | 1;
	break;
      case 0x30:
      case 0x34:
	prglo = (outb & ~14) | (prg << 1 & 14);
	prghi = (outb & ~14) | (prg << 1 & 14) | 1;
	break;
      // bottom fixed modes
      case 0x08:
	prglo = outb;
	prghi = outb | (prg & 1);
	break;
      case 0x18:
	prglo = outb;
	prghi = (outb & ~2) | (prg & 3);
	break;
      case 0x28:
	prglo = outb;
	prghi = (outb & ~6) | (prg & 7);
	break;
      case 0x38:
	prglo = outb;
	prghi = (outb & ~14) | (prg & 15);
	break;
      // top fixed modes
      case 0x0c:
	prglo = outb | (prg & 1);
	prghi = outb | 1;
	break;
      case 0x1c:
	prglo = (outb & ~2) | (prg & 3);
	prghi = outb | 1;
	break;
      case 0x2c:
	prglo = (outb & ~6) | (prg & 7);
	prghi = outb | 1;
	break;
      case 0x3c:
	prglo = (outb & ~14) | (prg & 15);
	prghi = outb | 1;
	break;
    }
    prglo &= prg_mask_16k;
    prghi &= prg_mask_16k;

    fc->cart->setprg16(0x8000, prglo);
    fc->cart->setprg16(0xC000, prghi);
    fc->cart->setchr8(chr);
  }

  void WriteEXP(DECLFW_ARGS) {
    uint32 addr = A;
    uint8 value = V;
    if (addr >= 05000) reg = value & 0x81;
  }

  void WritePRG(DECLFW_ARGS) {
    uint8 value = V;
    switch (reg) {
      case 0x00:
	chr = value & 3;
	Mirror(value);
	break;
      case 0x01:
	prg = value & 15;
	Mirror(value);
	Sync();
	break;
      case 0x80:
	mode = value & 63;
	SyncMirror();
	Sync();
	break;
      case 0x81:
	outer = value & 63;
	Sync();
	break;
    }
  }

  void Reset() override {
    outer = 63;
    prg = 15;
    Sync();
  }

  void Power() override {
    prg_mask_16k = fc->cart->PRGsize[0] - 1;

    // EXP
    fc->fceu->SetWriteHandler(0x4020, 0x5FFF, [](DECLFW_ARGS) {
      ((Mapper28*)fc->fceu->cartiface)->WriteEXP(DECLFW_FORWARD);
    });

    // PRG
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper28*)fc->fceu->cartiface)->WritePRG(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);

    // WRAM
    fc->fceu->SetReadHandler(0x6000, 0x7FFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, Cart::CartBW);

    Reset();
  }

  void Close() override {}

  static void StateRestore(FC *fc, int version) {
    ((Mapper28 *)fc->fceu->cartiface)->Sync();
  }

  Mapper28(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({
	{&reg, 1, "REGS"},
	{&chr, 1, "CHR0"},
	{&prg, 1, "PRG0"},
	{&mode, 1, "MODE"},
	{&outer, 1, "OUTR"}});
  }
};
}

CartInterface *Mapper28_Init(FC *fc, CartInfo* info) {
  return new Mapper28(fc, info);
}
