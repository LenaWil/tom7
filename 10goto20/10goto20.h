
/* Basics to be included by any .cc file. */

#ifndef __10GOTO20_H
#define __10GOTO20_H

#include "SDL.h"
#include "SDL_thread.h"
#include "sdl/sdlutil.h"
#include "math.h"
#include "base.h"

// Local utilities
#include "sample.h"
#include "concurrency.h"

// TODO: Dithering? Could at least round to nearest rather
// than truncate.
static inline Sint16 DoubleTo16(double d) {
  if (d > 1.0) return 32767;
  // signed 16-bit int goes to -32768, but we never use
  // this sample value; symmetric amplitudes seem like
  // the right thing?
  else if (d < -1.0) return -32767;
  else return (Sint16)(d * 32767.0);
}

// Using 96khz for this prototype. It would be nice to make the
// rendering sample-rate agnostic, but let's get something working
// first.
#define SAMPLINGRATE 96000
// 64 gigs of ram gets us:
// 68719476736 bytes
// 8589934592  doubles
// 89478 seconds of audio at 96khz
// 24 hours mono
// 12 hours stereo

// XXX more digits?
#define PI 3.141592653589
#define TWOPI 6.28318530718

#endif
