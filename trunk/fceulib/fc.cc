
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
  
  cart = new Cart(this);
  fceu = new FCEU(this);
  fds = new FDS(this);
  filter = new Filter(this);
  ines = new INes(this);
  input = new Input(this);
  palette = new Palette(this);
  ppu = new PPU(this);
  sound = new Sound(this);
  unif = new Unif(this);
  vsuni = new VSUni(this);
  X = new X6502(this);
  state = new State(this);
  
  printf("Done creating FC at %p\n", this);
}

FC::~FC() {
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
}

FC fceulib__;
