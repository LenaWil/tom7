
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
 */

#include "mapinc.h"
#include "mmc3.h"

namespace {
struct UNLA9746 : public MMC3 {
  uint8 EXPREGS[8] = {};
  void UNLA9746Write(DECLFW_ARGS) {
    //   FCEU_printf("write raw %04x:%02x\n",A,V);
    switch (A & 0xE003) {
    case 0x8000:
      EXPREGS[1] = V;
      EXPREGS[0] = 0;
      break;
    case 0x8002:
      EXPREGS[0] = V;
      EXPREGS[1] = 0;
      break;
    case 0x8001: {
      uint8 bits_rev = ((V & 0x20) >> 5) | ((V & 0x10) >> 3) |
	((V & 0x08) >> 1) | ((V & 0x04) << 1);
      switch (EXPREGS[0]) {
      case 0x26: fc->cart->setprg8(0x8000, bits_rev); break;
      case 0x25: fc->cart->setprg8(0xA000, bits_rev); break;
      case 0x24: fc->cart->setprg8(0xC000, bits_rev); break;
      case 0x23: fc->cart->setprg8(0xE000, bits_rev); break;
      }
      switch (EXPREGS[1]) {
      case 0x0a:
      case 0x08:
	EXPREGS[2] = (V << 4);
	break;
      case 0x09:
	fc->cart->setchr1(0x0000, EXPREGS[2] | (V >> 1));
	break;
      case 0x0b:
	fc->cart->setchr1(0x0400, EXPREGS[2] | (V >> 1) | 1);
	break;
      case 0x0c:
      case 0x0e:
	EXPREGS[2] = (V << 4);
	break;
      case 0x0d:
	fc->cart->setchr1(0x0800, EXPREGS[2] | (V >> 1));
	break;
      case 0x0f:
	fc->cart->setchr1(0x0c00, EXPREGS[2] | (V >> 1) | 1);
	break;
      case 0x10:
      case 0x12:
	EXPREGS[2] = (V << 4);
	break;
      case 0x11:
	fc->cart->setchr1(0x1000, EXPREGS[2] | (V >> 1));
	break;
      case 0x14:
      case 0x16:
	EXPREGS[2] = (V << 4); 
	break;
      case 0x15:
	fc->cart->setchr1(0x1400, EXPREGS[2] | (V >> 1));
	break;
      case 0x18:
      case 0x1a:
	EXPREGS[2] = (V << 4); 
	break;
      case 0x19:
	fc->cart->setchr1(0x1800, EXPREGS[2] | (V >> 1));
	break;
      case 0x1c:
      case 0x1e:
	EXPREGS[2] = (V << 4); 
	break;
      case 0x1d:
	fc->cart->setchr1(0x1c00, EXPREGS[2] | (V >> 1));
	break;
      }
    } break;
    }
  }

  void Power() override {
    MMC3::Power();
    fc->fceu->SetWriteHandler(0x8000, 0xbfff, [](DECLFW_ARGS) {
	((UNLA9746*)fc->fceu->cartiface)->UNLA9746Write(DECLFW_FORWARD);
      });
  }

  UNLA9746(FC *fc, CartInfo *info) : MMC3(fc, info, 128, 256, 0, 0) {
    fc->state->AddExState(EXPREGS, 6, 0, "EXPR");
  }
};
}

CartInterface *UNLA9746_Init(FC *fc, CartInfo *info) {
  return new UNLA9746(fc, info);
}
