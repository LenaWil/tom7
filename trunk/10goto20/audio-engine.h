
/* This is the central audio rendering and output engine.

   There is just one global audio engine, since there's one song and
   one pair of speakers.
 */


#ifndef __AUDIO_ENGINE_H
#define __AUDIO_ENGINE_H

#include "10goto20.h"
#include "sample-layer.h"

struct AudioEngine {

  static void Init();

  // There is a single playback cursor, which is always within the
  // array of samples (or one past its end). The engine can move and
  // stop the cursor. Nominally, the song begins at sample 0, but it
  // is possible for layers to extend before the song, so sample
  // indices are signed. The cursor indicates the next sample to play.
  static void SetCursor(int64 sample);
  static int64 GetCursor();

  // Replace the current song with the argument. Returns the
  // current song. Takes ownership of the argument and relinquishes
  // ownership of the return value, which btw may be null.
  static SampleLayer *SwapLayer(SampleLayer *s);

  // Mark the first sample index not in the song. Must be
  // non-negative, since it must not be before the beginning point,
  // which is always 0.
  static void SetEnd(int64 end);

  // Whether output is occurring. The audio engine pauses itself if
  // the playback cursor reaches unrendered audio, so the display
  // engine should be checking this.
  static bool Playing();
  // Set the playing state. Audio can pause itself at any time,
  // including immediately after a call to Play (essentially
  // rejecting the call.)
  static void Play(bool play);

 private:
  // All static.
  AudioEngine() = delete;
  AudioEngine(const AudioEngine &) = delete;
};

#endif
