#include <math.h>

// This no longer interacts with SDL
// and ought to be ported to SML

// number of samples per second
//#define RATE 22050
//#define RATE 44100
#define RATE (44100 * 4)


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

#define INST_NONE   0
#define INST_SQUARE 1
#define INST_SAW    2
#define INST_NOISE  3
#define INST_SINE   4

volatile int cur_freq[NMIX];
volatile int cur_vol[NMIX];
volatile int cur_inst[NMIX];
static   int val[NMIX];
static float leftover[NMIX];
static   int samples[NMIX];

// is this guaranteed to be 16-bit?
typedef signed short int Sint16;

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
      case INST_SINE: {
	samples[ch] ++;
	double cycle = (((double)RATE * HZFACTOR) / cur_freq[ch]);
	/* as a fraction of cycle */
	double t = fmod(samples[ch], cycle);
	mag += (int) ( (double)cur_vol[ch] * sin((t/cycle) * 2.0 * PI) );

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

	/* half-volume for noise, otherwise too overpowering */
	if (cur_vol[ch]) mag += (seed % (cur_vol[ch] * 2) - cur_vol[ch]) >> 1;
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
   (probably) be harmless--but we would want to at least
   change the vol/freq/inst atomically. */
void ml_setfreq(int ch, int nf, int nv, int inst) {
  cur_freq[ch] = nf;
  cur_vol[ch] = nv;
  cur_inst[ch] = inst;
  samples[ch] = 0;
}

void ml_initsound() {
  int i;
  for (i = 0; i < NMIX; i ++) {
    cur_freq[i] = 256;
    cur_vol[i] = 0;
    samples[i] = 0;
    cur_inst[i] = INST_NONE;
    val[i] = 1;
  }
}
