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
 */

#include "mapinc.h"

static constexpr int WRAMSIZE = 8192;

namespace {
struct LH53 : public CartInterface {
  uint8 reg = 0, IRQa = 0;
  int32 IRQCount = 0;
  uint8 *WRAM = nullptr;

  void Sync() {
    fc->cart->setchr8(0);
    fc->cart->setprg8(0x6000, reg);
    fc->cart->setprg8(0x8000, 0xc);
    fc->cart->setprg4(0xa000, (0xd << 1));
    fc->cart->setprg2(0xb000, (0xd << 2) + 2);
    fc->cart->setprg2r(0x10, 0xb800, 4);
    fc->cart->setprg2r(0x10, 0xc000, 5);
    fc->cart->setprg2r(0x10, 0xc800, 6);
    fc->cart->setprg2r(0x10, 0xd000, 7);
    fc->cart->setprg2(0xd800, (0xe << 2) + 3);
    fc->cart->setprg8(0xe000, 0xf);
  }

  void LH53RamWrite(DECLFW_ARGS) {
    WRAM[(A - 0xB800) & 0x1FFF] = V;
  }

  void LH53Write(DECLFW_ARGS) {
    reg = V;
    Sync();
  }

  void LH53IRQaWrite(DECLFW_ARGS) {
    IRQa = V & 2;
    IRQCount = 0;
    if (!IRQa) fc->X->IRQEnd(FCEU_IQEXT);
  }

  void LH53IRQ(int a) {
    if (IRQa) {
      IRQCount += a;
      if (IRQCount > 7560) fc->X->IRQBegin(FCEU_IQEXT);
    }
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0xB800, 0xD7FF, [](DECLFW_ARGS) {
      ((LH53*)fc->fceu->cartiface)->LH53RamWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xE000, 0xEFFF, [](DECLFW_ARGS) {
      ((LH53*)fc->fceu->cartiface)->LH53IRQaWrite(DECLFW_FORWARD);
    });
    fc->fceu->SetWriteHandler(0xF000, 0xFFFF, [](DECLFW_ARGS) {
      ((LH53*)fc->fceu->cartiface)->LH53Write(DECLFW_FORWARD);
    });
  }

  void Close() override {
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((LH53*)fc->fceu->cartiface)->Sync();
  }

  LH53(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((LH53*)fc->fceu->cartiface)->LH53IRQ(a);
    };
    fc->fceu->GameStateRestore = StateRestore;

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    fc->state->AddExVec({
	{&reg, 1, "REGS"}, {&IRQa, 1, "IRQA"}, {&IRQCount, 4, "IRQC"}});
  }

};
}

CartInterface *LH53_Init(FC *fc, CartInfo *info) {
  return new LH53(fc, info);
}
