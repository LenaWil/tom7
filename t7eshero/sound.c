#include <SDL.h>
#include <SDL_audio.h>

// number of samples per second
//#define RATE 22050
#define RATE 44100
#define PI 3.14152653589
/* 512 = "A good value for games" */
#define BUFFERSIZE 512
// #define BUFFERSIZE 44100
#define NCHANNELS 1

volatile int cur_freq = 256;
volatile int cur_vol  = 32000;

void mixaudio (void * unused, Sint16 * stream, int len) {
  /* total number of samples; used to get rate */
  /* XXX glitch every time this overflows; should mod by RATE? */
  static int samples = 0;
  static int val = 1;
  int i;
  /* length is actually in bytes; halve it */
  len >>= 1;
  for(i = 0; i < len; i ++) {
    samples ++;
    /* fraction of one second .. */
    //    float frac = ((float)samples / (float)RATE);
    /* the frequency is the number of cycles per second.
       so the length of one cycle in samples is RATE/cur_freq. 
    */

    volatile int cycle = (RATE / cur_freq);
    volatile int pos = samples % cycle;
#if 0
    stream[i] = (Sint16) sin( ((float)pos / (float)cycle) * 2.0 * PI );
#endif
    if (samples > cycle) {
      val = - val;
      samples = 0;
    }
    stream[i] = val * cur_vol;
  }
}

/* PERF not obvious that we need to or want to lock out
   audio here, since changing the frequency within a buffer
   would give us better response time and a data race would
   (probably) be harmless */
void ml_setfreq(int nf, int nv) {
  SDL_LockAudio();
  cur_freq = nf;
  cur_vol = nv;
  SDL_UnlockAudio();
}

void ml_initsound() {
  SDL_AudioSpec fmt;

  /* Set 16-bit stereo audio at 22Khz */
  fmt.freq = RATE;
  fmt.format = AUDIO_S16SYS;
  fmt.channels = NCHANNELS;
  fmt.samples = BUFFERSIZE;
  fmt.callback = (void(*)(void*, Uint8*, int)) mixaudio;
  fmt.userdata = NULL;

  SDL_AudioSpec got;

  // XXX should check that we got the desired settings...
  if ( SDL_OpenAudio(&fmt, &got) < 0 ) {
    fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
    exit(1);
  }

  printf("Audio data: %d samples, %d channels, %d rate\n",
	 got.samples, got.channels, got.freq);

  SDL_PauseAudio(0);
}
