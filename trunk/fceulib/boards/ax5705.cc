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
 * Super Bros. Pocker Mali (VRC4 mapper)
 */

#include "mapinc.h"

namespace {
struct UNLAX5705 : public CartInterface {
  uint8 IRQCount = 0;  //, IRQPre;
  uint8 IRQa = 0;
  uint8 prg_reg[2] = {};
  uint8 chr_reg[8] = {};
  uint8 mirr = 0;

  /*
  static void UNLAX5705IRQ()
  {
    if(IRQa)
    {
      IRQCount++;
      if(IRQCount>=238)
      {
        fc->X->IRQBegin(FCEU_IQEXT);
  //      IRQa=0;
      }
    }
  }*/

  void Sync() {
    fc->cart->setprg8(0x8000, prg_reg[0]);
    fc->cart->setprg8(0xA000, prg_reg[1]);
    fc->cart->setprg8(0xC000, ~1);
    fc->cart->setprg8(0xE000, ~0);
    for (int i = 0; i < 8; i++) fc->cart->setchr1(i << 10, chr_reg[i]);
    fc->cart->setmirror(mirr ^ 1);
  }

  void UNLAX5705Write(DECLFW_ARGS) {
    //  if((A>=0xA008)&&(A<=0xE003))
    //  {
    //    int ind=(((A>>11)-6)|(A&1))&7;
    //    int sar=((A&2)<<1);
    //    chr_reg[ind]=(chr_reg[ind]&(0xF0>>sar))|((V&0x0F)<<sar);
    //    SyncChr();
    //  }
    //  else
    switch (A & 0xF00F) {
      case 0x8000:
	// EPROM dump have mixed PRG and CHR banks, data lines to mapper
	// seems to be mixed
        prg_reg[0] = ((V & 2) << 2) | ((V & 8) >> 2) | (V & 5);
        break;
      case 0x8008:
	mirr = V & 1; 
	break;
      case 0xA000:
	prg_reg[1] = ((V & 2) << 2) | ((V & 8) >> 2) | (V & 5); 
	break;
      case 0xA008:
	chr_reg[0] = (chr_reg[0] & 0xF0) | (V & 0x0F); 
	break;
      case 0xA009:
        chr_reg[0] = (chr_reg[0] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xA00A:
	chr_reg[1] = (chr_reg[1] & 0xF0) | (V & 0x0F); 
	break;
      case 0xA00B:
        chr_reg[1] = (chr_reg[1] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xC000:
	chr_reg[2] = (chr_reg[2] & 0xF0) | (V & 0x0F); 
	break;
      case 0xC001:
        chr_reg[2] = (chr_reg[2] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xC002:
	chr_reg[3] = (chr_reg[3] & 0xF0) | (V & 0x0F); 
	break;
      case 0xC003:
        chr_reg[3] = (chr_reg[3] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xC008:
	chr_reg[4] = (chr_reg[4] & 0xF0) | (V & 0x0F); 
	break;
      case 0xC009:
        chr_reg[4] = (chr_reg[4] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xC00A:
	chr_reg[5] = (chr_reg[5] & 0xF0) | (V & 0x0F); 
	break;
      case 0xC00B:
        chr_reg[5] = (chr_reg[5] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xE000: 
	chr_reg[6] = (chr_reg[6] & 0xF0) | (V & 0x0F); 
	break;
      case 0xE001:
        chr_reg[6] = (chr_reg[6] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
      case 0xE002:
	chr_reg[7] = (chr_reg[7] & 0xF0) | (V & 0x0F);
	break;
      case 0xE003:
        chr_reg[7] = (chr_reg[7] & 0x0F) |
                     ((((V & 4) >> 1) | ((V & 2) << 1) | (V & 0x09)) << 4);
        break;
        //    case 0x800A: fc->X->IRQEnd(FCEU_IQEXT); IRQa=0; break;
        //    case 0xE00B: fc->X->IRQEnd(FCEU_IQEXT); IRQa=IRQCount=V;
        //    /*if(scanline<240) IRQCount-=8; else IRQCount+=4;*/  break;
    }
    Sync();
  }

  void Power() override {
    Sync();
    fc->fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
    fc->fceu->SetWriteHandler(0x8000, 0xFFFF, [](DECLFW_ARGS) {
	((UNLAX5705*)fc->fceu->cartiface)->UNLAX5705Write(DECLFW_FORWARD);
      });
  }

  static void StateRestore(FC *fc, int version) {
    ((UNLAX5705*)fc->fceu->cartiface)->Sync();
  }

  UNLAX5705(FC *fc, CartInfo *info) : CartInterface(fc) {
    //  GameHBIRQHook=UNLAX5705IRQ;
    fc->fceu->GameStateRestore = StateRestore;
    fc->state->AddExVec({{&IRQCount, 1, "IRQC"}, {&IRQa, 1, "IRQA"},
                         {prg_reg, 2, "PRG0"}, {chr_reg, 8, "CHR0"},
                         {&mirr, 1, "MIRR"}});
  }
};
}

CartInterface *UNLAX5705_Init(FC *fc, CartInfo *info) {
  return new UNLAX5705(fc, info);
}
