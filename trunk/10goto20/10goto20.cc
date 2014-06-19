
#include "10goto20.h"
#include "audio-engine.h"

#include "sample-layer.h"
#include "music-layer.h"

#include "bleep-bloop-sample-layer.h"
#include "midi-music-layer.h"
#include "wavesave.h"
#include "mix-layer.h"
#include "play-music-layer.h"

#define STARTW 800
#define STARTH 600

#define AUDIOBUFFER 1024

// XXX this stuff needs to go into audio-engine.
static SampleLayer *layer;

int64 ttt = 0LL;

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

// TODO: much better clamping, please! 
struct SorryLayer : public SampleLayer {
  explicit SorryLayer(SampleLayer *layer) : layer(layer) {}
  bool FirstSample(int64 *t) { return layer->FirstSample(t); }
  bool AfterLastSample(int64 *t) { return layer->AfterLastSample(t); }
  Sample SampleAt(int64 t) {
    Sample s = layer->SampleAt(t);
    if (s.left > 1.0) s.left = 1.0;
    else if (s.left < -1.0) s.left = -1.0;
    if (s.right > 1.0) s.right = 1.0;
    else if (s.right < -1.0) s.right = -1.0;
    return s;
  }
  SampleLayer *layer;
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
    PlayMusicLayer::Instrument inst = (i % 2) ? PlayMusicLayer::SAWTOOTH :
      PlayMusicLayer::SQUARE;
    plays.push_back(PlayMusicLayer::Create(midis[i], inst));
  }

  MixLayer *ml = MixLayer::Create(plays);

  layer = new SorryLayer(ml);
  CHECK(layer);

  // First make and write wave, for debugging.
  {
    int64 nsamples = SAMPLINGRATE * 10;
    vector<pair<float, float>> samples;
    for (int64 i = 0; i < nsamples; i++) {
      Sample s = layer->SampleAt(i);
      samples.push_back(make_pair((float)s.left, (float)s.right));
    }
    WaveSave::SaveStereo("sensations.wav", samples, SAMPLINGRATE);
    printf("Wrote wave.\n");
  }

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

  fprintf(stderr, "Audio started: %d Hz %d buffer\n",
	  obtained.freq, obtained.samples);

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
