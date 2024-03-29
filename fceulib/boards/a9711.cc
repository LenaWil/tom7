/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2005 CaH4e3
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
#include "mmc3.h"

// static uint8 m_perm[8] = {0, 1, 0, 3, 0, 5, 6, 7};

namespace {
struct UNLA9711 : public MMC3 {
  uint8 EXPREGS[8] = {};
  
  void PWrap(uint32 A, uint8 V) override {
    if ((EXPREGS[0] & 0xFF) == 0x37) {
      fc->cart->setprg8(0x8000, 0x13);
      fc->cart->setprg8(0xA000, 0x13);
      fc->cart->setprg8(0xC000, 0x13);
      fc->cart->setprg8(0xE000, 0x0);
      //	  uint8 bank=EXPREGS[0]&0x1F;
      //	 if(EXPREGS[0]&0x20)
      //	    setprg32(0x8000,bank>>2);
      //	  else
      //	  {
      //	    setprg16(0x8000,bank);
      //	    setprg16(0xC000,bank);
      //	  }
    } else {
      fc->cart->setprg8(A, V & 0x3F);
    }
  }

  // static DECLFW(UNLA9711Write8000)
  //{
  //	FCEU_printf("bs %04x %02x\n",A,V);
  //	if(V&0x80)
  //	  MMC3_CMDWrite(A,V);
  //	else
  //	  MMC3_CMDWrite(A,m_perm[V&7]);
  //	if(V!=0x86) MMC3_CMDWrite(A,V);
  //}

  void UNLA9711WriteLo(DECLFW_ARGS) {
    // FCEU_printf("bs %04x %02x\n", A, V);
    EXPREGS[0] = V;
    FixMMC3PRG(MMC3_cmd);
  }

  void Power() override {
    EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = 0;
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x5000, 0x5FFF, [](DECLFW_ARGS) {
      ((UNLA9711*)fc->fceu->cartiface)->UNLA9711WriteLo(DECLFW_FORWARD);
    });
    //	fc->fceu->SetWriteHandler(0x8000,0xbfff,UNLA9711Write8000);
  }

  UNLA9711(FC *fc, CartInfo *info) : MMC3(fc, info, 256, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 3, 0, "EXPR");
  }

};
}

CartInterface *UNLA9711_Init(FC *fc, CartInfo *info) {
  return new UNLA9711(fc, info);
}
