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

// number of simultaneous polyphonic notes
#define NMIX 12

#define MAX_MIX (32700)
#define MIN_MIX (-32700)

#define INST_NONE   0
#define INST_SQUARE 1
#define INST_SAW    2
#define INST_NOISE  3

volatile int cur_freq[NMIX];
volatile int cur_vol[NMIX];
volatile int cur_inst[NMIX];
static   int val[NMIX];

void mixaudio (void * unused, Sint16 * stream, int len) {
  /* total number of samples; used to get rate */
  /* XXX glitch every time this overflows; should mod by RATE? */
  static int samples[NMIX];
  static int seed;
  int i, ch;
  /* length is actually in bytes; halve it */
  len >>= 1;
  for(i = 0; i < len; i ++) {
    int mag = 0;

    /* compute the mixed magnitude of all channels,
       based on the current state of each channel */
    for(ch = 0; ch < NMIX; ch ++) {

      switch(cur_inst[ch]) {
      case INST_SAW:
	samples[ch] ++;
	int cycle = ((RATE * 100) / cur_freq[ch]);
	int pos = samples[ch] % cycle;
	/* sweeping from -vol to +vol with period 'cycle' */
	mag += -cur_vol[ch] + (int)( ((float)pos / cycle) * 2.0 * cur_vol[ch] );

	break;
      case INST_SQUARE: {
	samples[ch] ++;
	/* the frequency is the number of cycles per one hundred seconds.
	   so the length of one cycle in samples is (RATE*100)/cur_freq. 
	*/
	
	// PERF this should be the value stored in cur_freq
	int cycle = ((RATE * 100) / cur_freq[ch]);
	// int pos = samples[ch] % cycle;
	if (samples[ch] > cycle) {
	  val[ch] = - val[ch];
	  samples[ch] = 0;
	}
	mag += val[ch] * cur_vol[ch];
	break;
      }
      case INST_NOISE:
	seed ^= 0xDEADBEEF;
	seed *= 0x11234567;
	seed += 0x77339919;

	if (cur_vol[ch]) mag += seed % (cur_vol[ch] * 2) - cur_vol[ch];
	break;
      }

    }
    /* PERF clipping seems to happen automatically in the cast? */
    if (mag > MAX_MIX) mag = MAX_MIX;
    else if (mag < MIN_MIX) mag = MIN_MIX;

    stream[i] = (Sint16) mag;
  }
}

/* PERF not obvious that we need to or want to lock out
   audio here, since changing the frequency within a buffer
   would give us better response time and a data race would
   (probably) be harmless */
void ml_setfreq(int ch, int nf, int nv, int inst) {
  SDL_LockAudio();
  cur_freq[ch] = nf;
  cur_vol[ch] = nv;
  cur_inst[ch] = inst;
  SDL_UnlockAudio();
}

void ml_initsound() {
  SDL_AudioSpec fmt;

  {
    int i;
    for (i = 0; i < NMIX; i ++) {
      cur_freq[i] = 256;
      cur_vol[i] = 0;
      val[i] = 1;
    }
  }

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

  fprintf(stderr, "Audio data: %d samples, %d channels, %d rate\n",
	  got.samples, got.channels, got.freq);
  
  fprintf(stderr, "%d\n", (int)(Sint16)(int)(90000));

  SDL_PauseAudio(0);
}
