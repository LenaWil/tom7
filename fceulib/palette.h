#ifndef __PALETTE_H
#define __PALETTE_H

// struct Palette {

struct PaletteEntry {
  uint8 r,g,b;
};

extern const PaletteEntry *palo;
extern uint8 pale;
void FCEU_ResetPalette(void);

void FCEU_ResetPalette(void);
void FCEU_ResetMessages();
void FCEU_LoadGamePalette(void);

// };

#endif
