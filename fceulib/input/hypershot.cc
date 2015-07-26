/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2003 Xodnizel
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

#include <string.h>
#include "share.h"

namespace {
struct HyperShot : public InputCFC {
  using InputCFC::InputCFC;
  
  uint8 Read(int w, uint8 ret) override {
    if (w) ret |= HSValR;
    return ret;
  }

  void Strobe(void) override {
    HSValR = HSVal << 1;
  }

  void Update(void *data, int arg) override {
    HSVal = *(uint8 *)data;
  }

  uint8 HSVal = 0, HSValR = 0;
};
}  // namespace

extern InputCFC *CreateHS(FC *fc) {
  return new HyperShot(fc);
}
