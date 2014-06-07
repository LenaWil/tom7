
/* This is the basic audio rendering and output engine.

   There is just one global audio engine, since there's one song and
   one pair of speakers.
 */


#ifndef __AUDIO_ENGINE_H
#define __AUDIO_ENGINE_H

#include "10goto20.h"
#include "sample-layer.h"

struct AudioEngine {

  static void Init();

  // There is a single playback cursor, which is always within
  // the array of samples. The engine can move and stop the cursor.
  // Nominally, the song begins at sample 0, but it is possible
  // for layers to extend before the song, so sample indices are
  // signed.
  static void SetCursor(int64 sample);
  static int64 GetCursor();

  // Whether output is occurring. The audio engine pauses itself if
  // the playback cursor reaches unrendered audio, so the display
  // engine should be checking this.
  static bool Playing();
  // Set the playing state. Audio can pause itself at any time.
  static void Play(bool play);

 private:
  static SDL_mutex *mutex;
  static int64 cursor;
  static bool playing;
  static SampleLayer *song;
};

#endif
