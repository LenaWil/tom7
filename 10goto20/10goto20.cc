
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

int main (int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  fprintf(stderr, "10 GOTO 20\n");

  vector<MidiMusicLayer *> midis = MidiMusicLayer::Create("sensations.mid");
// XXX use it...

  layer = BleepBloopSampleLayer::Create();
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
