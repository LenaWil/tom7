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
struct Mapper76 : public MapInterface {
  using MapInterface::MapInterface;
  uint8 MMC3_cmd = 0;

  void Mapper76_write(DECLFW_ARGS) {
    switch (A & 0xE001) {
      case 0x8000: MMC3_cmd = V; break;
      case 0x8001:
	switch (MMC3_cmd & 0x07) {
	  case 2: VROM_BANK2(fc, 0x000, V); break;
	  case 3: VROM_BANK2(fc, 0x800, V); break;
	  case 4: VROM_BANK2(fc, 0x1000, V); break;
	  case 5: VROM_BANK2(fc, 0x1800, V); break;
	  case 6:
	    if (MMC3_cmd & 0x40)
	      ROM_BANK8(fc, 0xC000, V);
	    else
	      ROM_BANK8(fc, 0x8000, V);
	    break;
	  case 7: ROM_BANK8(fc, 0xA000, V); break;
	}
	break;
      case 0xA000: fc->ines->MIRROR_SET(V & 1); break;
    }
  }
};
}
  
MapInterface *Mapper76_init(FC *fc) {
  fc->fceu->SetWriteHandler(0x8000, 0xffff, [](DECLFW_ARGS) {
    ((Mapper76*)fc->fceu->mapiface)->Mapper76_write(DECLFW_FORWARD);
  });
  return new Mapper76(fc);
}
