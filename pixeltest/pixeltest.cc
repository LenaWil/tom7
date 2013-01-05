
#include "pixeltest.h"

#define STARTW 800
#define STARTH 600

int main (int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  fprintf(stderr, "PIXEL TEST\n");

  //  MidiMusicLayer *midi = MidiMusicLayer::Create("sensations.mid");
  //   CHECK(midi);
// XXX use it...

  SDL_EnableUNICODE(1);
  SDL_Surface *screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, 1234567);
  SDL_Flip(screen);

#if 0
  SDL_AudioSpec spec, obtained;
  spec.freq = SAMPLINGRATE;
  spec.samples = 2048;
  spec.channels = 2;
  spec.callback = &Audio;
  spec.userdata = 0;
  spec.format = AUDIO_S16SYS;
  SDL_OpenAudio(&spec, &obtained);

  fprintf(stderr, "hey. %d %d\n", obtained.freq, obtained.samples);

  SDL_PauseAudio(0);

  SDL_Thread *t1 = SDL_CreateThread(waste, 0);
  SDL_Thread *t2 = SDL_CreateThread(waste, 0);
  SDL_Thread *t3 = SDL_CreateThread(waste, 0);
  SDL_Thread *t4 = SDL_CreateThread(waste, 0);
  SDL_Thread *t5 = SDL_CreateThread(waste, 0);
  SDL_Thread *t6 = SDL_CreateThread(waste, 0);
#endif

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
