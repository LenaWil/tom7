
/* Compile-time settings. These used to be part of a global FCEUS object,
   but that approach makes thread safety trickier. It would not be tricky
   to move these constants into the fceu object if they need to be set
   individually and differently for distinct instances. */

#ifndef __FCEULIB_FSETTINGS_H
#define __FCEULIB_FSETTINGS_H

// 0-150 scale.
#define FCEUS_SOUNDVOLUME 150
// 0-256 scale
#define FCEUS_TRIANGLEVOLUME 256
#define FCEUS_SQUARE1VOLUME 256
#define FCEUS_SQUARE2VOLUME 256
#define FCEUS_NOISEVOLUME 256
#define FCEUS_PCMVOLUME 256

// First and last rendered scanlines. Same for PAL as NTSC.
// 
//   static constexpr int scanlinestart = 0, scanlineend = 239;
// 
//   FCEUI_SetRenderedLines(scanlinestart + 8, scanlineend - 8, 
// 			 scanlinestart, scanlineend);
// 
// Note: These are not used anywhere. Maybe they are really for
// clients.
#define FCEUS_NTSC_FIRSTSLINE (0 + 8)
#define FCEUS_NTSC_LASTSLINE (239 - 8)
#define FCEUS_PAL_FIRSTSLINE 0
#define FCEUS_PAL_LASTSLINE 239

// Sets up sound code to render sound at the specified rate, in samples
// per second.  Only sample rates of 44100, 48000, and 96000 are currently supported.
// If "Rate" equals 0, sound is disabled.
#define FCEUS_SNDRATE 44100

// Change sound quality. Looks like this can be 0, 1, or 2.
#define FCEUS_SOUNDQ 0

// Enable lowpass filter, presumably?
#define FCEUS_LOWPASS 0

#endif
