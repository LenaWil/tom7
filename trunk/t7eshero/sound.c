#include <SDL.h>
#include <SDL_audio.h>
#include <math.h>

// number of samples per second
//#define RATE 22050
#define RATE 44100

#define PI 3.14152653589
/* 512 = "A good value for games" */
#define BUFFERSIZE 512
// #define BUFFERSIZE 44100
#define NCHANNELS 1

/* frequencies are supplied by the client
   in 1/HZFACTOR Hz increments */
#define HZFACTOR 10000

// number of simultaneous polyphonic notes
#define NMIX 12

#define MAX_MIX (32700)
#define MIN_MIX (-32700)

#define VOL_FACTOR (0.2)

#define INST_NONE   0
#define INST_SQUARE 1
#define INST_SAW    2
#define INST_NOISE  3
#define INST_SINE   4
#define INST_RHODES 5

#define SAMPLER_OFFSET 1024
#define MAX_WAVES 8192
#define MAX_SETS 128

#define ENV_FADEIN_SAMPLES 32
#define ENV_FADEOUT_SAMPLES 32

volatile int cur_freq[NMIX];
volatile int cur_vol[NMIX];
volatile int cur_inst[NMIX];
static   int val[NMIX];
static float leftover[NMIX];
// Arbitrary integer data associated with the channel's state.
// For periodic instruments, it stores the number of samples
// that have transpired. For noise, it stores the previous sample
// value for filtering.
static   int samples[NMIX];
// If -1, do nothing special. if >= 0, for that many samples, continue
// making the current sound, decreasing it in volume and decreasing fades,
// until reaching -1, and then set the instrument to NONE and volume to 0.
static   int fades[NMIX];

#define NBANDS 8
static   int oldpass[NMIX][NBANDS];

// Waves that have been registered and copied into memory.
static struct {
  int nsamples;
  Sint16 *samples;
} waves[MAX_WAVES];
static int num_waves;

// Sample sets that have been registered. Each int is an
// index into the waves array above.
static int sets[MAX_SETS][128];
static int num_sets;

void mixaudio (void * unused, Sint16 * stream, int len) {
  /* total number of samples; used to get rate */
  /* XXX glitch every time this overflows; should mod by RATE? */
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
      case INST_NONE: break;
      case INST_RHODES: {
	// XXX
      } 
	/* FALLTHROUGH */
      case INST_SINE: {
	double cycle = (((double)RATE * HZFACTOR) / cur_freq[ch]);
	/* as a fraction of cycle */
	double t = fmod(samples[ch], cycle);
	double val = ( (double)cur_vol[ch] * sin((t/cycle) * 2.0 * PI) );
	if (samples[ch] < ENV_FADEIN_SAMPLES) {
	  val *= (samples[ch] / (float)ENV_FADEIN_SAMPLES);
	}
	// printf("Fading %d @%d\n", ch, fades[ch]);
	if (fades[ch] >= 0) {
	  fades[ch] --;
	  val *= (fades[ch] / (float)ENV_FADEOUT_SAMPLES);
	}

	mag += (int) val;
	samples[ch] ++;

 	if (fades[ch] == 0) {
	  // printf("Fade ends for %d.\n", ch);
	  cur_inst[ch] = INST_NONE;
	  cur_vol[ch] = 0;
	  fades[ch] = -1;
	}

	break;
      }
      case INST_SAW: {
	samples[ch] ++;
	double cycle = (((double)RATE * HZFACTOR) / cur_freq[ch]);
	double pos = fmod(samples[ch], cycle);
	/* sweeping from -vol to +vol with period 'cycle' */
	mag += -cur_vol[ch] + (int)( (pos / cycle) * 2.0 * cur_vol[ch] );

	break;
      }
      case INST_SQUARE: {
	samples[ch] ++;
	/* the frequency is the number of cycles per HZFACTOR seconds.
	   so the length of one cycle in samples is (RATE*HZFACTOR)/cur_freq. 
	*/
#if 0	
	// PERF this should be the value stored in cur_freq
	float fcycle = (((float)RATE * HZFACTOR) / cur_freq[ch]);
	int cycle = (int)fcycle;
	leftover[ch] += (fcycle - cycle);
	// int pos = samples[ch] % cycle;
	if (samples[ch] >= cycle) {
	  val[ch] = - val[ch];
	  /* at higher frequencies, the difference in
	     the sample period gets to be close to 1 sample, so
	     we have a relatively large effect from floating point
	     roundoff. Correct for this by accumulating error
	     and making a longer period when we have a whole sample.
	  */
	  if (1 && leftover[ch] > 1.0) {
	    samples[ch] = -1;
	    leftover[ch] -= 1.0;
	  } else {
	    samples[ch] = 0;
	  }
	}
	mag += val[ch] * cur_vol[ch];
#endif
	double cycle = (((double)RATE * HZFACTOR) / cur_freq[ch]);
	double pos = fmod(samples[ch], cycle);
	/* sweeping from -vol to +vol with period 'cycle' */
	mag += (pos > (cycle/2.0))?cur_vol[ch]:-cur_vol[ch];

	break;
      }
      case INST_NOISE:
	seed ^= 0xDEADBEEF;
	seed *= 0x11234567;
	seed += 0x77339919;

	/* quarter-volume for noise, otherwise too overpowering */
	if (cur_vol[ch]) {
	  int samp = (seed % (cur_vol[ch] * 2) - cur_vol[ch]) >> 2;

	  // lowpass filter. Should really do a bandpass where the
	  // cutoffs are some interval around the target frequency.

	  int i, freq = HZFACTOR * 16;
	  for(i = 0; i < NBANDS; i ++, freq <<= 1) {
            #define ALPHA 0.7
	    if (cur_freq[ch] < freq) {
	      samp = oldpass[ch][i] + ALPHA * (samp - oldpass[ch][i]);
	      samp = samp * (1.2);
	    }
	    oldpass[ch][i] = samp;
	  }

	  mag += samp * 0.75;
	}
	break;
      default: {
	// FIXME: Multithreading!
	int w = cur_inst[ch] - SAMPLER_OFFSET;
	if (w < 0 || w >= num_sets) {
	  fprintf(stderr, "Instrument %d unknown (or sample %d out of range)\n", 
		  cur_inst[ch], w);
	  abort();
	} 
	if (samples[ch] < waves[sets[w][cur_freq[ch]]].nsamples) {
	  // Need to modulate for volume...
	  mag += waves[sets[w][cur_freq[ch]]].samples[samples[ch]]; // * cur_vol[ch];
	  samples[ch]++;
	}
      }
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
   (probably) be harmless--but we would want to at least
   change the vol/freq/inst atomically.

   FIXME: data race is bad for sampler.
 */
void ml_setfreq(int ch, int nf, int nv, int inst) {
  // SDL_LockAudio();
#if 1
  if (ch < 11 /* && inst >= SAMPLER_OFFSET */) { // || inst != INST_NONE) {
    printf("(cur inst: %d) Set %d = %d (Hz/10000) %d %d\n", cur_inst[ch], ch, nf, nv, inst);
      //      if (nf < HZFACTOR * 2000) printf ("BANDPASS.");
    }
#endif

  if ((nv == 0 || inst == INST_NONE) && (cur_inst[ch] == INST_SINE || cur_inst[ch] == INST_RHODES)) {

    // printf("Made ch %d start fading\n", ch);
    // set fadeout samples.
    fades[ch] = ENV_FADEOUT_SAMPLES;

  } else {
    cur_vol[ch] = (int)(VOL_FACTOR * (float)nv);
    cur_freq[ch] = nf;
    cur_inst[ch] = inst;
    fades[ch] = -1;
    
    if (inst == INST_NOISE) {
      int i;
      for(i = 0; i < NBANDS; i ++) oldpass[ch][i] = 0;
    } else {
      samples[ch] = 0;
    }
  }
  // SDL_UnlockAudio();
}

void ml_initsound() {
  SDL_AudioSpec fmt;

  // Erase all waves.
  {
    int i;
    for (i = 0; i < MAX_WAVES; i++) {
      waves[i].nsamples = 0;
      waves[i].samples = 0;
    }
    // Register 0 wave as silence.
    num_waves = 1;
  }

  // Erase all sample sets.
  {
    int i, j;
    for(i = 0; i < MAX_SETS; i++) {
      for(j = 0; j < 128; j++) {
	sets[i][j] = 0;
      }
    } 
    num_sets = 0;
  }

  {
    int i;
    for (i = 0; i < NMIX; i ++) {
      cur_freq[i] = 256;
      cur_vol[i] = 0;
      samples[i] = 0;
      cur_inst[i] = INST_NONE;
      val[i] = 1;
      fades[i] = -1;
    }
  }

  /* Set 16-bit stereo audio at sample rate RATE */
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

int ml_sampleroffset () {
  return SAMPLER_OFFSET;
}

int ml_register_sample (int * v, int n) {
  if (num_waves == MAX_WAVES) {
    fprintf(stderr, "Exceed the maximum number of waves\n");
    abort();
  }
  waves[num_waves].nsamples = n;
  waves[num_waves].samples = (Sint16*) malloc(sizeof (Sint16) * n);
  {
    int i;
    for(i = 0; i < n; i++) {
      waves[num_waves].samples[i] = v[i];
    }
  }
  return num_waves++;
}

// Here the vector contains 
int ml_register_sampleset (int * v, int n) {
  if (n != 128) {
    fprintf(stderr, "Wanted sampler to have size 128, got %d\n", n);
    abort();
  } else if (num_sets == MAX_SETS) {
    fprintf(stderr, "Exceeded the maximum number of sample sets\n");
    abort();
  } else {
    int i;
    for(i = 0; i < 128; i++) {
      sets[num_sets][i] = v[i];
    }
    return num_sets++;
  }
}
