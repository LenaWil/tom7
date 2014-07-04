
/* This is the central audio rendering and output engine.

   There is just one global audio engine, since there's one song and
   one pair of speakers. Internally synchronized and thread-safe,
   though it relies on the thread safety of the layers it's built of.
 */


#ifndef __AUDIO_ENGINE_H
#define __AUDIO_ENGINE_H

#include "10goto20.h"
#include "sample-layer.h"
#include "interval-cover.h"
#include "revision.h"

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
  // TODO: Should this really be maintained through the audio engine?
  static int64 GetEnd();

  // Whether output is occurring. The audio engine pauses itself if
  // the playback cursor reaches unrendered audio, so the display
  // engine should be checking this.
  static bool Playing();
  // Set the playing state. Audio can pause itself at any time,
  // including immediately after a call to Play (essentially
  // rejecting the call.)
  static void Play(bool play);

  // Render the whole song (i.e., bring up to the current revision)
  // and don't return until it's done. TODO: Threaded version!
  static void BlockingRender();

  // For drawing the status of rendering. Thread safe but doesn't keep
  // the lock, and therefore may be instantly out of date -- so it
  // should not be used for logic, just display.
  static pair<IntervalCover<int>, IntervalCover<Revision>> GetSpans();

 private:
  ALL_STATIC(AudioEngine);
};

#endif
