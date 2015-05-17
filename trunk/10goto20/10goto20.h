
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
#include "logging.h"

// We use these interchangeably; ensure that they are consistent.
// The S* and U* versions come from SDL, the simple ones from base.h.
// (TODO: Is there a way to check that the types are literally
// the same?)
static_assert(sizeof(Sint64) == sizeof(int64), "int 64");
static_assert(sizeof(Uint64) == sizeof(uint64), "uint 64");
static_assert(sizeof(Sint32) == sizeof(int32), "int 32");
static_assert(sizeof(Uint32) == sizeof(uint32), "uint 32");
static_assert(sizeof(Sint16) == sizeof(int16), "int 16");
static_assert(sizeof(Uint16) == sizeof(uint16), "uint 16");
static_assert(sizeof(Uint8) == sizeof(uint8), "uint 8");

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

#define PI 3.14159265358979323846264338327950288419716939937510
#define TWOPI (2.0 * PI) // 6.28318530718

#endif
