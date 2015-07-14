
#include "fc.h"

#include "cart.h"
#include "fceu.h"
#include "fds.h"
#include "filter.h"
#include "ines.h"
#include "input.h"
#include "palette.h"
#include "ppu.h"
#include "sound.h"
#include "tracing.h"
#include "unif.h"
#include "vsuni.h"
#include "x6502.h"
#include "state.h"

FC::FC() {
  // Paranoia: Make sure that attempts to access
  // other objects during initialization at least
  // see nullptr.
  cart = nullptr;
  fceu = nullptr;
  fds = nullptr;
  filter = nullptr;
  ines = nullptr;
  input = nullptr;
  palette = nullptr;
  ppu = nullptr;
  sound = nullptr;
  unif = nullptr;
  vsuni = nullptr;
  X = nullptr;
  state = nullptr;

  printf("Creating FC at %p\n", this);
  
  cart = new Cart;
  fceu = new FCEU;
  fds = new FDS;
  filter = new Filter;
  ines = new INes(this);
  input = new Input;
  palette = new Palette;
  ppu = new PPU;
  sound = new Sound(this);
  unif = new Unif;
  vsuni = new VSUni;
  X = new X6502(this);
  state = new State;
  
  printf("Done creating FC at %p\n", this);
}

FC::~FC() {
  printf("Destroying fc at %p.\n");
  delete cart;
  delete fceu;
  delete fds;
  delete filter;
  delete ines;
  delete input;
  delete palette;
  delete ppu;
  delete sound;
  delete unif;
  delete vsuni;
  delete X;
  delete state;
  printf("Done destroying fc at %p.\n");
}

FC fceulib__;
