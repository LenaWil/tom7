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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef __UNIF_H
#define __UNIF_H

#include "fceu.h"

struct FceuFile;

// The "Universal NES Image Format" is a basically deprecated ROM
// image format.
//
// http://wiki.nesdev.com/w/index.php/UNIF

struct Unif {
  Unif();

  int UNIFLoad(const char *name, FceuFile *fp);
  // So I can stop CHR RAM bank switcherooing with certain boards...
  uint8 *UNIFchrrama = nullptr;
 private:

  struct UNIF_HEADER {
    char ID[4];
    uint32 info;
  };

  void UNIFGI(GI h);

  void ResetUNIF();
  int LoadUNIFChunks(FceuFile *fp);
  int InitializeBoard();

  int EnableBattery(FceuFile *fp);
  int LoadPRG(FceuFile *fp);
  int CTRL(FceuFile *fp);
  int TVCI(FceuFile *fp);
  int DoMirroring(FceuFile *fp);
  int LoadCHR(FceuFile *fp);
  int NAME(FceuFile *fp);
  int SetBoardName(FceuFile *fp);
  int DINF(FceuFile *fp);

  void MooMirroring();
  void FreeUNIF();

  CartInfo UNIFCart = {};

  int vramo = 0;
  int mirrortodo = 0;
  uint8 *boardname = nullptr;
  uint8 *sboardname = nullptr;
  uint32 CHRRAMSize = 0;
  UNIF_HEADER unhead = {};
  UNIF_HEADER uchead = {};

  uint8 *malloced[32] = {0};
  uint32 mallocedsizes[32] = {0};

  uint8 exntar[2048] = {0};
};

#endif
