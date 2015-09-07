// This is an internal instance of the emulator, used to aggregate all of
// the objects together. You could think of it as being a single NES,
// which can load a cartridge and emulate steps, but also save and restore
// state.

#ifndef __FC_H
#define __FC_H

// These are deliberately forward-declared in this header so that
// it can be safely included anywhere.
struct Cart;
struct FCEU;
struct FDS;
struct Filter;
struct INes;
struct Input;
struct Palette;
struct PPU;
struct Sound;
struct Unif;
struct VSUni;
struct X6502;
struct State;

struct FC {
  Cart *cart;
  FCEU *fceu;
  FDS *fds;
  Filter *filter;
  INes *ines;
  Input *input;
  Palette *palette;
  PPU *ppu;
  Sound *sound;
  Unif *unif;
  VSUni *vsuni;
  X6502 *X;
  State *state;
  
  FC();
  ~FC();
};

// extern FC fceulib__;

#endif
