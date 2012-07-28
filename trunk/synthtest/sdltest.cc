
#include "SDL.h"
#include "SDL_audio.h"
#include "sdl/sdlutil.h"
#include "math.h"

#define STARTW 800
#define STARTH 600

int ttt = 0;
bool hi = false;

void Audio(void *userdata, Uint8 *stream_bytes, int num_bytes) {
  Sint16 *stream = (Sint16*) stream_bytes;
  int samples = num_bytes / sizeof (Sint16);

  for (int i = 0; i < samples; i++) {
    ttt++;
if (ttt > 1000) {
ttt = 0;
hi = !hi;
}
stream[i] = hi ? 6000 : -6000;
// stream[i] = (Sint16) (0x1286341 ^ (ttt * 0x123486));
  }

}

int main (int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }


  SDL_EnableUNICODE(1);
  SDL_Surface *screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, 1234567);
  SDL_Flip(screen);

  SDL_AudioSpec spec, obtained;
  spec.freq = 44100;
  spec.samples = 1024;
  spec.channels = 1;
  spec.callback = &Audio;
  spec.userdata = 0;
  spec.format = AUDIO_S16SYS;
  SDL_OpenAudio(&spec, &obtained);

  fprintf(stderr, "hey. %d %d\n", obtained.freq, obtained.samples);

  SDL_PauseAudio(0);

  while(1) {
    SDL_Delay(0);
  }

  return 0;
}
