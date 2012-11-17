/* This tests the interface to the emulator library
   for correctness, by playing back the movie karate.fm2
   against the rom karate.nes, and checking that
   the game is won and that the RAM has the right
   contents. It also does some simple timing. */

#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <limits.h>
#include <math.h>

#include <zlib.h>

#include "fceu/utils/md5.h"

#include "config.h"

#include "fceu/driver.h"
#include "fceu/drivers/common/args.h"

#include "fceu/state.h"

#include "fceu/drivers/common/cheat.h"
#include "fceu/fceu.h"
#include "fceu/movie.h"
#include "fceu/version.h"

#include "fceu/oldmovie.h"
#include "fceu/types.h"

#include "../cc-lib/util.h"

#include "simplefm2.h"
#include "emulator.h"

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
 * Update the video, audio, and input subsystems with the provided
 * video (XBuf) and audio (Buffer) information.
 */
void FCEUD_Update(uint8 *XBuf, int32 *Buffer, int Count) {
}

static int64 DumpMem() {
  for (int i = 0; i < 0x800; i++) {
    fprintf(stderr, "%02x", (uint8)RAM[i]);
    // if (i % 40 == 0) fprintf(stderr, "\n");
  }
  md5_context ctx;
  md5_starts(&ctx);
  md5_update(&ctx, RAM, 0x800);
  uint8 digest[16];
  md5_finish(&ctx, digest);
  fprintf(stderr, "  MD5: ");
  for (int i = 0; i < 16; i++)
    fprintf(stderr, "%02x", digest[i]);
  fprintf(stderr, "\n");
  return *(int64*)digest;
}

static void CheckLoc(int frame, uint32 expected) {
  fprintf(stderr, "Frame %d expect %u\n", frame, expected);
  uint32 loc = (RAM[0x0080] << 24) |
    (RAM[0x0081] << 16) |
    (RAM[0x0082] << 8) |
    (RAM[0x0083]);
  if (loc != expected) {
    fprintf(stderr, "At frame %d, expected %u, got %u\n",
	    frame, expected, loc);
    abort();
  }
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  Emulator::Initialize("karate.nes");
  // loop playing the game
  vector<uint8> inputs = SimpleFM2::ReadInputs("karate.fm2");
  fprintf(stderr, "Running %d steps...\n", inputs.size());

  for (int i = 0; i < inputs.size(); i++) {
    // XXX don't think this should ever happen.
    if (!GameInfo) {
      fprintf(stderr, "Gameinfo became null?\n");
      return -1;
    }

    Emulator::Step(inputs[i]);

    // XXX read from golden file.
    // The FCEUX UI indexes frames starting at 1.
    const int fceu_frame = i + 1;
    switch (fceu_frame) {
    case 20: CheckLoc(fceu_frame, 0); break;
    case 21: CheckLoc(fceu_frame, 65536); break;
    case 4935: CheckLoc(fceu_frame, 196948); break;
    case 7674: CheckLoc(fceu_frame, 200273); break;
    case 7675: CheckLoc(fceu_frame, 200274); break;
    case 8123: CheckLoc(fceu_frame, 262144); break;
    case 11213: CheckLoc(fceu_frame, 265916); break;
    default:;
    }
  }

  fprintf(stderr, "final mem: %llx\n", DumpMem());


  if (0x46e75713b56aea30 == Emulator::RamChecksum()) {
    fprintf(stderr, "Memory OK.\n");
  } else {
    fprintf(stderr, "WRONG CHECKSUM\n");
    return -1;
  }

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}
