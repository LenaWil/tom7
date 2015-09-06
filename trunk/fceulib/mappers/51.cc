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
struct Mapper51 : public MapInterface {
  using MapInterface::MapInterface;
  
  #define mode(fc) GMB_mapbyte1(fc)[0]
  #define page(fc) GMB_mapbyte1(fc)[1]

  uint32 Get8K(uint32 A) {
    uint32 bank = (page(fc) << 2) | ((A >> 13) & 1);

    if (A & 0x4000 && !(mode(fc) & 1)) bank |= 0xC;
    if (!(A & 0x8000)) bank |= 0x20;
    if (mode(fc) == 2)
      bank |= 2;
    else
      bank |= (A >> 13) & 2;
    return (bank);
  }

  void Synco() {
    if (GMB_mapbyte1(fc)[0] <= 2)
      fc->ines->MIRROR_SET2(1);
    else
      fc->ines->MIRROR_SET2(0);
    for (uint32 x = 0x6000; x < 0x10000; x += 8192)
      ROM_BANK8(fc, x, Get8K(x));
  }

  void Write(DECLFW_ARGS) {
    if (A & 0x8000)
      GMB_mapbyte1(fc)[1] = V & 0xF;
    else
      GMB_mapbyte1(fc)[0] = (GMB_mapbyte1(fc)[0] & 2) | ((V >> 1) & 1);

    if (A & 0x4000)
      GMB_mapbyte1(fc)[0] = (GMB_mapbyte1(fc)[0] & 1) | ((V >> 3) & 2);
    Synco();
  }
};
}
  
MapInterface *Mapper51_init(FC *fc) {
  Mapper51 *m = new Mapper51(fc);
  fc->fceu->SetWriteHandler(0x6000, 0xFFFF, [](DECLFW_ARGS) {
    ((Mapper51*)fc->fceu->mapiface)->Write(DECLFW_FORWARD);
  });
  fc->fceu->SetReadHandler(0x6000, 0xFFFF, Cart::CartBR);
  GMB_mapbyte1(fc)[0] = 1;
  GMB_mapbyte1(fc)[1] = 0;
  m->Synco();
  return m;
}
