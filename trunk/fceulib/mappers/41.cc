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

#define calreg GMB_mapbyte1(fc)[0]
#define calchr GMB_mapbyte1(fc)[1]

namespace {
struct Mapper41 : public MapInterface {
  using MapInterface::MapInterface;
  
  void Mapper41_write(DECLFW_ARGS) {
    if (A < 0x8000) {
      ROM_BANK32(fc, A & 7);
      fc->ines->MIRROR_SET((A >> 5) & 1);
      calreg = A;
      calchr &= 0x3;
      calchr |= (A >> 1) & 0xC;
      VROM_BANK8(fc, calchr);
    } else if (calreg & 0x4) {
      calchr &= 0xC;
      calchr |= A & 3;
      VROM_BANK8(fc, calchr);
    }
  }

  void MapperReset() override {
    calreg = calchr = 0;
  }
};
}

MapInterface *Mapper41_init(FC *fc) {
  ROM_BANK32(&fceulib__, 0);
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper41*)fc->fceu->mapiface)->Mapper41_write(DECLFW_FORWARD);
  });
  fc->fceu->SetWriteHandler(0x6000, 0x67ff, [](DECLFW_ARGS) {
    ((Mapper41*)fc->fceu->mapiface)->Mapper41_write(DECLFW_FORWARD);
  });
  return new Mapper41(fc);
}
