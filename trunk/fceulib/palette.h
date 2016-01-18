#ifndef __PALETTE_H
#define __PALETTE_H

#include "fc.h"

struct PaletteEntry {
  uint8 r, g, b;
};

struct Palette {
 public:
  explicit Palette(FC *fc);

  const PaletteEntry *palo = nullptr;
  uint8 pale = 0;

  void ResetPalette();
  void LoadGamePalette();
  void SetNESDeemph(uint8 d, int force);
  void FCEUI_SetNTSCTH(int n, int tint, int hue);

  // Gets the color for a particular index in the palette.
  void FCEUD_GetPalette(uint8 index, uint8 *r, uint8 *g, uint8 *b) const;

 private:
  int ntsccol = 0;
  int ntsctint = 46+10;
  int ntschue = 72;

  uint8 lastd = 0;

  int ipalette = 0;

  /* These are dynamically filled/generated palettes: */
  PaletteEntry palettei[64];       // Custom palette for an individual game.
  PaletteEntry paletten[64];       // Mathematically generated palette.

  void CalculatePalette();
  void ChoosePalette();
  void WritePalette();

  void FCEUI_GetNTSCTH(int *tint, int *hue);

  void FCEUD_SetPalette(uint8 index, uint8 r, uint8 g, uint8 b);

  struct Color {
    Color() : r(0), g(0), b(0) {}
    uint8 r, g, b;
  };
  Color s_psdl[256] = {};

  FC *fc = nullptr;
};

#endif
