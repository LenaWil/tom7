
#include "10goto20.h"
#include "audio-engine.h"

#include "sample-layer.h"
#include "music-layer.h"

#include "bleep-bloop-sample-layer.h"
#include "midi-music-layer.h"

#define STARTW 800
#define STARTH 600

#define AUDIOBUFFER 1024

static SampleLayer *layer;

int64 ttt = 0LL;

// XXX dithering, etc.
static Sint16 DoubleTo16(double d) {
  if (d > 1.0) return 32767;
  // signed 16-bit int goes to -32768, but we never use
  // this sample value; symmetric amplitudes seem like
  // the right thing?
  else if (d < -1.0) return -32767;
  else return (Sint16)(d * 32767.0);
}

void Audio(void *userdata, Uint8 *stream_bytes, int num_bytes) {
  Sint16 *stream = (Sint16*) stream_bytes;
  int samples = num_bytes / sizeof (Sint16);

  // Two channels.
  for (int i = 0; i < samples; i += 2) {
    Sample s = layer->SampleAt(ttt);
    stream[i] = DoubleTo16(s.left);
    stream[i + 1] = DoubleTo16(s.right);
    ttt++;
  }
}

struct PlayMidiLayer : public SampleLayer {
  // Does not take ownership.
  explicit PlayMidiLayer(MidiMusicLayer *midi) : midi(midi) {}
  
  
  bool FirstSample(int64 *t) { return midi->FirstSample(t); }
  bool AfterLastSample(int64 *t) { return midi->AfterLastSample(t); }

  Sample SampleAt(int64 t) {
    // TODO: Implement each instrument or whatever.
    // printf("Get notes %lld\n", t);
    vector<Controllers> cs = midi->NotesAt(t);
    // printf("%lld notes\n", cs.size());
    Sample ret(0.0);
    for (int i = 0; i < cs.size(); i++) {
      const Controllers &c = cs[i];
      double seconds = t / (double)SAMPLINGRATE;
      double freq = c.GetRequired(FREQUENCY);
      double d = sin(TWOPI * freq * seconds);
      // printf("sec %f freq %f d %f\n", seconds, freq, d);
      // XXX implement amplitude too
      // printf("%f/%f\n", ret.left, ret.right);
      ret = ret + Sample(d) * 0.5;
    }
    // printf("%f/%f\n", ret.left, ret.right);
    return ret;
  }

 private:
  MidiMusicLayer *midi;
};

struct MixLayer : public SampleLayer {
  MixLayer(const vector<SampleLayer *> &layers) : layers(layers) {
    lb = ub = 0;
    bool hasl = false, hasu = false;
    right_infinite = left_infinite = false;
    for (int i = 0; i < layers.size(); i++) {
      SampleLayer *layer = layers[i];
      int64 t;
      if (layer->FirstSample(&t)) {
	if (!hasl || t < lb) {
	  hasl = true;
	  lb = t;
	}
      } else {
	left_infinite = true;
      }
      
      if (layer->AfterLastSample(&t)) {
	if (!hasl || t > ub) {
	  hasu = true;
	  ub = t;
	}
      } else {
	right_infinite = true;
      }
    }
  }
  
  bool FirstSample(int64 *t) {
    if (left_infinite) return false;
    *t = lb;
    return true;
  }

  bool AfterLastSample(int64 *t) {
    if (right_infinite) return false;
    *t = ub;
    return true;
  }

  Sample SampleAt(int64 t) {
    // XXX this asks for samples outside the finite range
    // for finite layers. Should maybe update the docs, or fix that?
    Sample s(0.0);
    for (int i = 0; i < layers.size(); i++) {
      s += layers[i]->SampleAt(t);
    }
    return s;
  }

 private:
  bool left_infinite, right_infinite;
  int64 lb, ub;
  const vector<SampleLayer *> layers;
};

int main (int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  fprintf(stderr, "10 GOTO 20\n");

  vector<MidiMusicLayer *> midis = MidiMusicLayer::Create("sensations.mid");

  vector<SampleLayer *> plays;
  for (int i = 0; i < midis.size(); i++) {
    plays.push_back(new PlayMidiLayer(midis[i]));
  }

  layer = new MixLayer(plays);
    // BleepBloopSampleLayer::Create();
  CHECK(layer);

  SDL_EnableUNICODE(1);
  SDL_Surface *screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, 1234567);
  SDL_Flip(screen);

  SDL_AudioSpec spec, obtained;
  spec.freq = SAMPLINGRATE;
  spec.samples = AUDIOBUFFER;
  spec.channels = 2;
  spec.callback = &Audio;
  spec.userdata = 0;
  spec.format = AUDIO_S16SYS;
  SDL_OpenAudio(&spec, &obtained);

  fprintf(stderr, "hey. %d %d\n", obtained.freq, obtained.samples);

  SDL_PauseAudio(0);

  while(1) {
    SDL_Event e;
    /* event loop */
    while (SDL_PollEvent(&e)) {
      switch(e.type) {
      case SDL_QUIT:
	return 0;

      case SDL_KEYDOWN: {
	int key = e.key.keysym.sym;
	switch(key) {
	case SDLK_ESCAPE:
	  return 0;
	default:;
	}
      }
	
      default:;
      }
    }

    SDL_Delay(0);
  }

  return 0;
}
