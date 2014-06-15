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
  
  virtual bool FirstSample(int64 *t);
  virtual bool AfterLastSample(int64 *t);
  virtual Sample SampleAt(int64 t) = 0;

 protected:
  explicit PlayMusicLayer(MusicLayer *music);
  MusicLayer *music;
};

#endif
