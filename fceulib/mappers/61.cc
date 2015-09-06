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
struct Mapper61 : public MapInterface {
  using MapInterface::MapInterface;
  
  void Mapper61_write(DECLFW_ARGS) {
    // printf("$%04x:$%02x\n",A,V);
    switch (A & 0x30) {
    case 0x00:
    case 0x30: ROM_BANK32(fc, A & 0xF); break;
    case 0x20:
    case 0x10:
      ROM_BANK16(fc, 0x8000, ((A & 0xF) << 1) | (((A & 0x20) >> 4)));
      ROM_BANK16(fc, 0xC000, ((A & 0xF) << 1) | (((A & 0x20) >> 4)));
      break;
    }
  #ifdef moo
    if (!(A & 0x10))
      ROM_BANK32(fc, A & 0xF);
    else {
      ROM_BANK16(fc, 0x8000, ((A & 0xF) << 1) | (((A & 0x10) >> 4) ^ 1));
      ROM_BANK16(fc, 0xC000, ((A & 0xF) << 1) | (((A & 0x10) >> 4) ^ 1));
    }
  #endif
    fc->ines->MIRROR_SET((A & 0x80) >> 7);
  }
};
}

MapInterface *Mapper61_init(FC *fc) {
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper61 *)fc->fceu->mapiface)->Mapper61_write(DECLFW_FORWARD);
  });
  return new Mapper61(fc);
}
