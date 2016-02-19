/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2002,2003 Xodnizel
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

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "types.h"
#include "file.h"
#include "fceu.h"
#include "driver.h"
#include "boards/mapinc.h"

#include "palette.h"
#include "palettes/palettes.h"

// TODO: Now that these are compile-time constants, some of this stuff
// can be shared instead of per-instance.
static constexpr int NTSCCOL = 0;
static constexpr int NTSCTINT = 46 + 10;
static constexpr int NTSCHUE = 72;

static constexpr double PALETTE_PI = 3.14159265358979323846;

static constexpr PaletteEntry const *palpoint[] = {
  default_palette, rp2c04001, rp2c04002, rp2c04003, rp2c05004,
};

Palette::Palette(FC *fc) : fc(fc) {}

void Palette::FCEUD_GetPalette(uint8 index, uint8 *r, uint8 *g,
                               uint8 *b) const {
  *r = s_psdl[index].r;
  *g = s_psdl[index].g;
  *b = s_psdl[index].b;
}

void Palette::FCEUD_SetPalette(uint8 index, uint8 r, uint8 g, uint8 b) {
  s_psdl[index].r = r;
  s_psdl[index].g = g;
  s_psdl[index].b = b;
}

void Palette::SetNESDeemph(uint8 d, int force) {
  static constexpr uint16 rtmul[7] = {
      (uint16)(32768 * 1.239), (uint16)(32768 * .794),  (uint16)(32768 * 1.019),
      (uint16)(32768 * .905),  (uint16)(32768 * 1.023), (uint16)(32768 * .741),
      (uint16)(32768 * .75)};
  static constexpr uint16 gtmul[7] = {
      (uint16)(32768 * .915),  (uint16)(32768 * 1.086), (uint16)(32768 * .98),
      (uint16)(32768 * 1.026), (uint16)(32768 * .908),  (uint16)(32768 * .987),
      (uint16)(32768 * .75)};
  static constexpr uint16 btmul[7] = {
      (uint16)(32768 * .743),  (uint16)(32768 * .882), (uint16)(32768 * .653),
      (uint16)(32768 * 1.277), (uint16)(32768 * .979), (uint16)(32768 * .101),
      (uint16)(32768 * .75)};

  uint32 r, g, b;

  /* If it's not forced (only forced when the palette changes), don't
     waste cpu time if the same deemphasis bits are set as the last
     call. */
  if (!force) {
    if (d == lastd) {
      return;
    }
  } else {
    /* Only set this when palette has changed. */
    r = rtmul[6];
    g = rtmul[6];
    b = rtmul[6];

    for (int x = 0; x < 0x40; x++) {
      uint32 m = palo[x].r;
      uint32 n = palo[x].g;
      uint32 o = palo[x].b;
      m = (m * r) >> 15;
      n = (n * g) >> 15;
      o = (o * b) >> 15;
      if (m > 0xff) m = 0xff;
      if (n > 0xff) n = 0xff;
      if (o > 0xff) o = 0xff;
      FCEUD_SetPalette(x | 0xC0, m, n, o);
    }
  }
  if (!d) return; /* No deemphasis, so return. */

  r = rtmul[d - 1];
  g = gtmul[d - 1];
  b = btmul[d - 1];

  for (int x = 0; x < 0x40; x++) {
    uint32 m = palo[x].r;
    uint32 n = palo[x].g;
    uint32 o = palo[x].b;
    m = (m * r) >> 15;
    n = (n * g) >> 15;
    o = (o * b) >> 15;
    if (m > 0xff) m = 0xff;
    if (n > 0xff) n = 0xff;
    if (o > 0xff) o = 0xff;

    FCEUD_SetPalette(x | 0x40, m, n, o);
  }

  lastd = d;
}

// Converted from Kevin Horton's qbasic palette generator.
void Palette::CalculatePalette() {
  static constexpr uint8 cols[16] = {0, 24, 21, 18, 15, 12, 9, 6,
                                     3, 0,  33, 30, 27, 0,  0, 0};
  static constexpr uint8 br1[4] = {6, 9, 12, 12};
  static constexpr double br2[4] = {0.29, 0.45, 0.73, 0.9};
  static constexpr double br3[4] = {0, 0.24, 0.47, 0.77};

  for (int x = 0; x <= 3; x++) {
    for (int z = 0; z < 16; z++) {
      double s = (double)NTSCTINT / 128;
      double luma = br2[x];
      if (z == 0) {
        s = 0;
        luma = ((double)br1[x]) / 12;
      }

      if (z >= 13) {
        s = luma = 0;
        if (z == 13) luma = br3[x];
      }

      double theta =
          PALETTE_PI *
          (double)(((double)cols[z] * 10 + (((double)NTSCHUE / 2) + 300)) /
                   (double)180);
      int r = (int)((luma + s * sin(theta)) * 256);
      int g = (int)((luma - (double)27 / 53 * s * sin(theta) +
                     (double)10 / 53 * s * cos(theta)) *
                    256);
      int b = (int)((luma - s * cos(theta)) * 256);

      if (r > 255) r = 255;
      if (g > 255) g = 255;
      if (b > 255) b = 255;
      if (r < 0) r = 0;
      if (g < 0) g = 0;
      if (b < 0) b = 0;

      paletten[(x << 4) + z].r = r;
      paletten[(x << 4) + z].g = g;
      paletten[(x << 4) + z].b = b;
    }
  }
  WritePalette();
}

void Palette::LoadGamePalette() {
  uint8 ptmp[192];
  FILE *fp;

  ipalette = 0;

  char *fn = strdup(FCEU_MakePaletteFilename().c_str());

  if ((fp = FCEUD_UTF8fopen(fn, "rb"))) {
    fread(ptmp, 1, 192, fp);
    fclose(fp);
    for (int x = 0; x < 64; x++) {
      palettei[x].r = ptmp[x + x + x];
      palettei[x].g = ptmp[x + x + x + 1];
      palettei[x].b = ptmp[x + x + x + 2];
    }
    ipalette = 1;
  }
  free(fn);
}

void Palette::ResetPalette() {
  if (fc->fceu->GameInfo != nullptr) {
    ChoosePalette();
    WritePalette();
  }
}

void Palette::ChoosePalette() {
  if (ipalette) {
    palo = palettei;
  } else if (NTSCCOL && !fc->fceu->PAL &&
             fc->fceu->GameInfo->type != GIT_VSUNI) {
    palo = paletten;
    CalculatePalette();
  } else {
    palo = palpoint[pale];
  }
}

void Palette::WritePalette() {
  for (int x = 0; x < 7; x++)
    FCEUD_SetPalette(x, unvpalette[x].r, unvpalette[x].g, unvpalette[x].b);

  for (int x = 0; x < 64; x++)
    FCEUD_SetPalette(128 + x, palo[x].r, palo[x].g, palo[x].b);
  SetNESDeemph(lastd, 1);
}

void Palette::FCEUI_GetNTSCTH(int *tint, int *hue) {
  *tint = NTSCTINT;
  *hue = NTSCHUE;
}
