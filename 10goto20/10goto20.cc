
// Just for LoadLibrary. Maybe could use an extern decl.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "10goto20.h"
#include "audio-engine.h"

#include "sample-layer.h"
#include "music-layer.h"

#include "bleep-bloop-sample-layer.h"
#include "midi-music-layer.h"
#include "wavesave.h"
#include "mix-layer.h"
#include "play-music-layer.h"
#include "revision.h"
#include "sorry-layer.h"
#include "util.h"

#define STARTW 1920
#define STARTH 1080

// TODO: Make into little library. Make constexpr mixcolor that's
// correct for the platform.
static constexpr Uint32 RGBA(uint8 r, uint8 g, uint8 b, uint8 a) {
  return (a << 24) |
    (r << 16) |
    (g << 8) |
    b;
}
static constexpr Uint32 RED = RGBA(0xFF, 0x0, 0x0, 0xFF);
static constexpr Uint32 BLACK = RGBA(0x0, 0x0, 0x0, 0xFF);
static constexpr Uint32 WHITE = RGBA(0xFF, 0xFF, 0xFF, 0xFF);
static constexpr Uint32 GREEN = RGBA(0x0, 0xFF, 0x0, 0xFF);
static constexpr Uint32 BLUE = RGBA(0x0, 0x0, 0xFF, 0xFF);
static constexpr Uint32 BACKGROUND = RGBA(0x00, 0x20, 0x00, 0xFF);

static SampleLayer *layer;
// XXX wither?
static SDL_Surface *screen;

int main(int argc, char **argv) {

  if (Util::ExistsFile("exchndl.dll")) {
    fprintf(stderr, "Found exchndl.dll; loading it...\n");
    // extern void LoadLibrary(const char *);
    LoadLibrary("exchndl.dll");
  }

  // and thread?
  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  Logging::Init();

  lprintf("10 GOTO 20\n");

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

#if 0
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
#endif

  Revisions::Init();
  AudioEngine::Init();

  AudioEngine::SwapLayer(layer);
  layer = nullptr;  // Owned by AE now.

  SDL_EnableUNICODE(1);
  screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, BACKGROUND); 
  SDL_Flip(screen);

  // AudioEngine::BlockingRender();
  AudioEngine::Play(true);

  auto Draw = []() {
    sdlutil::clearsurface(screen, BACKGROUND);

    const int64 screen_width = STARTW;
    const int64 song_end = AudioEngine::GetEnd();
    const double px_per_sample = (double)screen_width / (double)song_end;
    auto p = AudioEngine::GetSpans();
    const auto &sample_lock = p.first;
    const auto &sample_rev = p.second;

    // Draw locks.
    for (int64 pos = 0LL; pos < song_end; pos = sample_lock.Next(pos)) {
      auto span = sample_lock.GetPoint(pos);
      static const Uint32 thread_colors[] = {
	0xFFCCCCFF,
	0xCCFFCCFF,
	0xCCCCFFFF,
	0xFFFFCCFF,
	0xFFCCFFFF,
	0xCCFFFFFF,
      };
      static const int num_thread_colors = sizeof (thread_colors) /
	sizeof (Uint32);

      Uint32 color = RED;
      switch (span.data) {
      case -1: color = BLACK; break;
      case -2: color = RED; break;
      default: 
	CHECK(span.data >= 0);
	color = thread_colors[span.data % num_thread_colors];
      }

      int start = max(span.start, 0LL);
      int end = min(span.end, song_end);

      int startx = start * px_per_sample;
      int width = (int)(end * px_per_sample) - startx;
      sdlutil::fillrect(screen, color, startx, STARTH - 16,
			width, 8);
    }

    // Draw revisions.
    Revision r = Revisions::GetRevision();
    for (int64 pos = 0LL; pos < song_end; pos = sample_rev.Next(pos)) {
      auto span = sample_rev.GetPoint(pos);

      int start = max(span.start, 0LL);
      int end = min(span.end, song_end);

      Uint32 color = (span.data == r) ? GREEN : RED;
      int startx = start * px_per_sample;
      int width = (int)(end * px_per_sample) - startx;
      sdlutil::fillrect(screen, color, startx, STARTH - 8,
			width, 8);
    }

    // Draw cursor.
    int64 cursor = AudioEngine::GetCursor();
    int curx = cursor * px_per_sample;
    sdlutil::fillrect(screen, WHITE, 
		      curx, STARTH - 20,
		      1, 4);
  };

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
	case SDLK_SPACE: {
	  // XXX toggle
	  AudioEngine::Play(true);
	  break;
	}
	case SDLK_r: {
	  Revision r = Revisions::NextRevision();
	  lprintf("Incremented revision to %lld\n", r);
	  break;
	}
	case SDLK_ESCAPE:
	  return 0;
	default:;
	}
      }
	
      default:;
      }
    }

    // XXX cap at 30fps.
    Draw();
    SDL_Flip(screen);

    SDL_Delay(0);
  }

  return 0;
}
