
#ifndef __SOUND_H
#define __SOUND_H

#include "level.h"

/* This sound header is the same whether
   compiled with sound or not. */

#include "sound_enum.h"

struct sound {

  /* true if sound is available.
     it is safe to call any of these
     even if sound is not enabled,
     however. */
  static bool enabled();

  /* mute(true) turns off sound temporarily,
     mute(false) turns it back on */
  static void mute(bool domute);

  static void init();

  /* play sound s asynchronously.
     won't play if muted or disabled */
  static void play(sound_t s);

  /* okay to call even if sound initialization failed */
  static void shutdown();

};

#endif
