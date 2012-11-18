/* Searches for solutions to Karate Kid. */

#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "fceu/utils/md5.h"

#include "config.h"

#include "fceu/driver.h"
#include "fceu/drivers/common/args.h"

#include "fceu/state.h"

#include "fceu/fceu.h"
#include "fceu/types.h"

#include "../cc-lib/util.h"
#include "../cc-lib/heap.h"

#include "simplefm2.h"
#include "emulator.h"
#include "basis-util.h"




static void DoFun(int frameskip) {
  uint8 *gfx;
  int32 *sound;
  int32 ssize;
  static int opause = 0;

  // fprintf(stderr, "In DoFun..\n");

  // Limited ability to skip video and sound.
  #define SKIP_VIDEO_AND_SOUND 2

  // Emulate a single frame.
  FCEUI_Emulate(NULL, &sound, &ssize, SKIP_VIDEO_AND_SOUND);

  // This was the only useful thing from Update. It's called multiple
  // times; I don't know why.
  // --- update input! --

  uint8 v = RAM[0x0009];
  uint8 s = RAM[0x000B];  // Should be 77.
  uint32 loc = (RAM[0x0080] << 24) |
    (RAM[0x0081] << 16) |
    (RAM[0x0082] << 8) |
    (RAM[0x0083]);
  // fprintf(stderr, "%02x %02x\n", v, s);
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  Emulator::Initialize("karate.nes");

  // The inputs are only needed for computing the basis.
  vector<uint8> inputs = SimpleFM2::ReadInputs("karate.fm2");
  vector<uint8> basis = BasisUtil::LoadOrComputeBasis(inputs, 4935, "karate.basis");
  inputs.clear();

  fprintf(stderr, "Running %d steps...\n", inputs.size());
  for (int i = 0; i < inputs.size(); i++) {
    // XXX don't think this should ever happen.
    if (!GameInfo) {
      fprintf(stderr, "Gameinfo became null?\n");
      return -1;
    }

    vector<uint8> v;
    Emulator::SaveEx(&v, &basis);
    Emulator::Step(inputs[i]);
  }


  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}
