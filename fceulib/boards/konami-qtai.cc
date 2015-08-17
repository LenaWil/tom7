/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005-2008 CaH4e3
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
 * CAI Shogakko no Sansu
 */

#include "mapinc.h"

static constexpr int CHRSIZE = 8192;
static constexpr int WRAMSIZE = 8192 + 4096;

namespace {
struct Mapper190 : public CartInterface {
  uint8 QTAINTRAM[2048] = {};
  writefunc old2007wrap = nullptr;

  uint8 *CHRRAM = nullptr;
  uint8 *WRAM = nullptr;

  uint8 IRQa = 0, K4IRQ = 0;
  uint32 IRQLatch = 0, IRQCount = 0;

  uint8 regs[16] = {};

  void chrSync() {
    fc->cart->setchr4r(0x10, 0x0000, regs[5] & 1);
    fc->cart->setchr4r(0x10, 0x1000, 0);
  }

  void Sync() {
    chrSync();
    //  if(regs[0xA]&0x10)
    //  {
    /*    setchr1r(0x10,0x0000,(((regs[5]&1))<<2)+0);
	setchr1r(0x10,0x0400,(((regs[5]&1))<<2)+1);
	setchr1r(0x10,0x0800,(((regs[5]&1))<<2)+2);
	setchr1r(0x10,0x0c00,(((regs[5]&1))<<2)+3);
	setchr1r(0x10,0x1000,0);
	setchr1r(0x10,0x1400,1);
	setchr1r(0x10,0x1800,2);
	setchr1r(0x10,0x1c00,3);*/
    /*    setchr1r(0x10,0x0000,(((regs[5]&1))<<2)+0);
	setchr1r(0x10,0x0400,(((regs[5]&1))<<2)+1);
	setchr1r(0x10,0x0800,(((regs[5]&1))<<2)+2);
	setchr1r(0x10,0x0c00,(((regs[5]&1))<<2)+3);
	setchr1r(0x10,0x1000,(((regs[5]&1)^1)<<2)+4);
	setchr1r(0x10,0x1400,(((regs[5]&1)^1)<<2)+5);
	setchr1r(0x10,0x1800,(((regs[5]&1)^1)<<2)+6);
	setchr1r(0x10,0x1c00,(((regs[5]&1)^1)<<2)+7);
    */
    //  }
    //  else
    //  {
    /*
	setchr1r(0x10,0x0000,(((regs[5]&1)^1)<<2)+0);
	setchr1r(0x10,0x0400,(((regs[5]&1)^1)<<2)+1);
	setchr1r(0x10,0x0800,(((regs[5]&1)^1)<<2)+2);
	setchr1r(0x10,0x0c00,(((regs[5]&1)^1)<<2)+3);
	setchr1r(0x10,0x1000,(((regs[5]&1))<<2)+4);
	setchr1r(0x10,0x1400,(((regs[5]&1))<<2)+5);
	setchr1r(0x10,0x1800,(((regs[5]&1))<<2)+6);
	setchr1r(0x10,0x1c00,(((regs[5]&1))<<2)+7);
    //  }
    //*/
    fc->cart->setprg4r(0x10, 0x6000, regs[0] & 1);
    if (regs[2] >= 0x40)
      fc->cart->setprg8r(1, 0x8000, (regs[2] - 0x40));
    else
      fc->cart->setprg8r(0, 0x8000, (regs[2] & 0x3F));
    if (regs[3] >= 0x40)
      fc->cart->setprg8r(1, 0xA000, (regs[3] - 0x40));
    else
      fc->cart->setprg8r(0, 0xA000, (regs[3] & 0x3F));
    if (regs[4] >= 0x40)
      fc->cart->setprg8r(1, 0xC000, (regs[4] - 0x40));
    else
      fc->cart->setprg8r(0, 0xC000, (regs[4] & 0x3F));

    fc->cart->setprg8r(1, 0xE000, ~0);
    fc->cart->setmirror(MI_V);
  }

  void M190Write(DECLFW_ARGS) {
    // FCEU_printf("write %04x:%04x %d, %d\n",A,V,scanline,timestamp);
    regs[(A & 0x0F00) >> 8] = V;
    switch (A) {
      case 0xd600:
	IRQLatch &= 0xFF00;
	IRQLatch |= V;
	break;
      case 0xd700:
	IRQLatch &= 0x00FF;
	IRQLatch |= V << 8;
	break;
      case 0xd900:
	IRQCount = IRQLatch;
	IRQa = V & 2;
	K4IRQ = V & 1;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
      case 0xd800:
	IRQa = K4IRQ;
	fc->X->IRQEnd(FCEU_IQEXT);
	break;
    }
    Sync();
  }

  DECLFR_RET M190Read(DECLFR_ARGS) {
    // FCEU_printf("read %04x:%04x %d,
    // %d\n",A,regs[(A&0x0F00)>>8],scanline,timestamp);
    return regs[(A & 0x0F00) >> 8] + regs[0x0B];
  }
  
  void VRC5IRQ(int a) {
    if (IRQa) {
      IRQCount += a;
      if (IRQCount & 0x10000) {
	fc->X->IRQBegin(FCEU_IQEXT);
	//      IRQCount=IRQLatch;
      }
    }
  }

  void M1902007Wrap(DECLFW_ARGS) {
    if (A >= 0x2000) {
      if (regs[0xA] & 1)
	QTAINTRAM[A & 0x1FFF] = V;
      else
	old2007wrap(DECLFW_FORWARD);
    }
  }

  void Power() override {
    fc->cart->setprg4r(0x10, 0x7000, 2);

    old2007wrap = fc->fceu->GetWriteHandler(0x2007);
    fc->fceu->SetWriteHandler(0x2007, 0x2007, [](DECLFW_ARGS) {
      ((Mapper190*)fc->fceu->cartiface)->M1902007Wrap(DECLFW_FORWARD);
    });

    fc->fceu->SetReadHandler(0x6000, 0xFFFF, fc->cart->CartBR);
    fc->fceu->SetWriteHandler(0x6000, 0x7FFF, fc->cart->CartBW);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
      ((Mapper190*)fc->fceu->cartiface)->M190Write(DECLFW_FORWARD);
    });
    fc->fceu->SetReadHandler(0xDC00, 0xDC00, [](DECLFR_ARGS) {
      return ((Mapper190*)fc->fceu->cartiface)->M190Read(DECLFR_FORWARD);
    });
    fc->fceu->SetReadHandler(0xDD00, 0xDD00, [](DECLFR_ARGS) {
      return ((Mapper190*)fc->fceu->cartiface)->M190Read(DECLFR_FORWARD);
    });
    Sync();
  }

  void Close() override {
    free(CHRRAM);
    CHRRAM = nullptr;
    free(WRAM);
    WRAM = nullptr;
  }

  static void StateRestore(FC *fc, int version) {
    ((Mapper190*)fc->fceu->cartiface)->Sync();
  }

  Mapper190(FC *fc, CartInfo *info) : CartInterface(fc) {
    fc->fceu->GameStateRestore = StateRestore;

    fc->X->MapIRQHook = [](FC *fc, int a) {
      ((Mapper190*)fc->fceu->cartiface)->VRC5IRQ(a);
    };
    // PPU_hook=Mapper190_PPU;

    CHRRAM = (uint8 *)FCEU_gmalloc(CHRSIZE);
    fc->cart->SetupCartCHRMapping(0x10, CHRRAM, CHRSIZE, 1);
    fc->state->AddExState(CHRRAM, CHRSIZE, 0, "CRAM");

    WRAM = (uint8 *)FCEU_gmalloc(WRAMSIZE);
    fc->cart->SetupCartPRGMapping(0x10, WRAM, WRAMSIZE, 1);
    fc->state->AddExState(WRAM, WRAMSIZE, 0, "WRAM");

    if (info->battery) {
      info->SaveGame[0] = WRAM;
      info->SaveGameLen[0] = WRAMSIZE - 4096;
    }

    fc->state->AddExVec({
	{&IRQCount, 1, "IRQC"}, {&IRQLatch, 1, "IRQL"},
        {&IRQa, 1, "IRQA"},     {&K4IRQ, 1, "KIRQ"},
        {regs, 16, "REGS"}});
  }
};
}

CartInterface *Mapper190_Init(FC *fc, CartInfo *info) {
  return new Mapper190(fc, info);
}
