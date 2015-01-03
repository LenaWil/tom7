#ifndef __PALETTE_H
#define __PALETTE_H

struct PaletteEntry {
  uint8 r,g,b;
};

struct Palette {
 public:
  const PaletteEntry *palo = nullptr;
  uint8 pale = 0;

  void ResetPalette();
  void LoadGamePalette();
  void SetNESDeemph(uint8 d, int force);
  void FCEUI_SetNTSCTH(int n, int tint, int hue);

 private:
  int ntsccol = 0;
  int ntsctint = 46+10;
  int ntschue = 72;

  uint8 lastd = 0;

  int ipalette = 0;

  int controlselect = 0;
  int controllength = 0;

  /* These are dynamically filled/generated palettes: */
  PaletteEntry palettei[64];       // Custom palette for an individual game.
  PaletteEntry paletten[64];       // Mathematically generated palette.

  void CalculatePalette();
  void ChoosePalette();
  void WritePalette();

  void FCEUI_GetNTSCTH(int *tint, int *hue);
};

extern Palette fceulib__palette;

#endif
