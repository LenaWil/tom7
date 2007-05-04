#include <SDL.h>
#include <SDL_audio.h>

void mixaudio (void * unused, Uint8 * stream, int len) {
  static int seed = 0;
  int i;
  for(i = 0; i < len; i ++) {
    seed ++;
    stream[i] = (seed >> 1) & 255;
  }
}

void ml_initsound() {
  SDL_AudioSpec fmt;

  /* Set 16-bit stereo audio at 22Khz */
  fmt.freq = 22050;
  fmt.format = AUDIO_S16;
  fmt.channels = 2;
  fmt.samples = 512;        /* A good value for games */
  fmt.callback = mixaudio;
  fmt.userdata = NULL;

  // XXX should check that we got the desired settings...
  if ( SDL_OpenAudio(&fmt, NULL) < 0 ) {
    fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
    exit(1);
  }

  SDL_PauseAudio(0);
}
