/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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

namespace {
struct Mapper80Base : public MapInterface {
  const bool isfu = false;
  uint32 lastA = 0;
  uint8 CCache[8] = {};
  int ppu_last = -1;
  uint8 ppu_z = 0;
  
  void Fudou_PPU(uint32 A) {
    if (A >= 0x2000) return;

    A >>= 10;
    lastA = A;

    ppu_z = CCache[A];
    if (ppu_z != ppu_last) {
      fc->ines->onemir(ppu_z);
      ppu_last = ppu_z;
    }
  }

  void mira() {
    if (isfu) {
      CCache[0] = CCache[1] = GMB_mapbyte2(fc)[0] >> 7;
      CCache[2] = CCache[3] = GMB_mapbyte2(fc)[1] >> 7;

      for (int x = 0; x < 4; x++)
	CCache[4 + x] = GMB_mapbyte2(fc)[2 + x] >> 7;

      fc->ines->onemir(CCache[lastA]);
    } else {
      fc->ines->MIRROR_SET2(GMB_mapbyte1(fc)[0] & 1);
    }
  }

  void Mapper80_write(DECLFW_ARGS) {
    switch (A) {
    case 0x7ef0:
      GMB_mapbyte2(fc)[0] = V;
      VROM_BANK2(fc, 0x0000, (V >> 1) & 0x3F);
      mira();
      break;
    case 0x7ef1:
      GMB_mapbyte2(fc)[1] = V;
      VROM_BANK2(fc, 0x0800, (V >> 1) & 0x3f);
      mira();
      break;

    case 0x7ef2:
      GMB_mapbyte2(fc)[2] = V;
      VROM_BANK1(fc, 0x1000, V);
      mira();
      break;
    case 0x7ef3:
      GMB_mapbyte2(fc)[3] = V;
      VROM_BANK1(fc, 0x1400, V);
      mira();
      break;
    case 0x7ef4:
      GMB_mapbyte2(fc)[4] = V;
      VROM_BANK1(fc, 0x1800, V);
      mira();
      break;
    case 0x7ef5:
      GMB_mapbyte2(fc)[5] = V;
      VROM_BANK1(fc, 0x1c00, V);
      mira();
      break;
    case 0x7ef6:
      GMB_mapbyte1(fc)[0] = V;
      mira();
      break;
    case 0x7efa:
    case 0x7efb: ROM_BANK8(fc, 0x8000, V); break;
    case 0x7efd:
    case 0x7efc: ROM_BANK8(fc, 0xA000, V); break;
    case 0x7efe:
    case 0x7eff: ROM_BANK8(fc, 0xC000, V); break;
    }
  }

  void StateRestore(int version) override {
    mira();
  }

  Mapper80Base(FC *fc, bool isfu) : MapInterface(fc), isfu(isfu) {
    // 7f00-7fff battery backed ram inside mapper chip,
    // controlled by 7ef8 register, A8 - enable, FF - disable (?)
    fc->fceu->SetWriteHandler(0x4020, 0x7eff, [](DECLFW_ARGS) {
      ((Mapper80Base*)fc->fceu->mapiface)->Mapper80_write(DECLFW_FORWARD);
    });
  }
};
}

MapInterface *Mapper80_init(FC *fc) {
  return new Mapper80Base(fc, false);
}

MapInterface *Mapper207_init(FC *fc) {
  fc->ppu->PPU_hook = [](FC *fc, uint32 a) {
    ((Mapper80Base *)fc->fceu->mapiface)->Fudou_PPU(a);
  };
  return new Mapper80Base(fc, true);
}
