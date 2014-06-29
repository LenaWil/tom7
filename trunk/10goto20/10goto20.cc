
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

static SampleLayer *layer;

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

  // and thread?
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

  AudioEngine::Init();

  SDL_EnableUNICODE(1);
  SDL_Surface *screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, 1234567);
  SDL_Flip(screen);

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
