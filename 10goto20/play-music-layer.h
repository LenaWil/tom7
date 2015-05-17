/*
  Layer that generates samples from a music layer. 
  Right now this supports some basic instruments like
  SINE, SAWTOOTH, TRIANGLE, SQUARE.
  
  Of course there are an infinitude of different instruments.
  This could easily get out of hand. Need to think about
  the right abstraction.
*/

#ifndef __PLAY_MUSIC_LAYER_H
#define __PLAY_MUSIC_LAYER_H

#include <vector>

#include "10goto20.h"
#include "music-layer.h"
#include "sample-layer.h"


struct PlayMusicLayer : public SampleLayer {
  enum Instrument {
    SINE,
    SAWTOOTH,
    TRIANGLE,
    SQUARE,
  };

  static PlayMusicLayer *Create(MusicLayer *layer,
				Instrument inst);
  
  bool FirstSample(int64 *t) override;
  bool AfterLastSample(int64 *t) override;
  Sample SampleAt(int64 t) override = 0;

 protected:
  explicit PlayMusicLayer(MusicLayer *music);
  MusicLayer *music;
};

#endif
