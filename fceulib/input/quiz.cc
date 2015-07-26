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
struct QuizKing : public InputCFC {
  using InputCFC::InputCFC;

  uint8 Read(int w, uint8 ret) override {
    if (w) {
      // if(fceulib__.X->PC==0xdc7d) return(0xFF);
      // printf("Blah: %04x\n",fceulib__.X->PC);
      // FCEUI_DumpMem("dmp2",0xc000,0xffff);

      ret |= (QZValR & 0x7) << 2;
      QZValR = QZValR >> 3;

      if (FunkyMode) {
	// ret=0x14;
	// puts("Funky");
	QZValR |= 0x28;
      } else {
	QZValR |= 0x38;
      }
    }
    return (ret);
  }

  void Strobe() override {
    QZValR = QZVal;
    // puts("Strobe");
  }

  void Write(uint8 V) override {
    // printf("Wr: %02x\n",V);
    FunkyMode = V & 4;
  }

  void Update(void *data, int arg) override {
    QZVal = *(uint8 *)data;
  }

  uint8 QZVal = 0, QZValR = 0;
  uint8 FunkyMode = 0;
};
}  // namespace

InputCFC *CreateQuizKing(FC *fc) {
  return new QuizKing(fc);
}
  
