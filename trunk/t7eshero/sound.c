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

// number of simultaneous polyphonic notes:
// 11 regular, 1 miss effect, 5 drums
// (but the ML code can allocate these however it likes.)
#define NMIX 17

#define MAX_MIX (32700)
#define MIN_MIX (-32700)


#define MAX_VOL (127 * 90)
#define MAX_VOL_INVF (1.0f / (127 * 90))

#define VOL_FACTOR (0.2f)

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
// Arbitrary integer data associated with the channel's state.
// For periodic instruments, it stores the number of samples
// that have transpired. For noise, it is unused. For waves, it stores
// the number of samples that we have emitted so far.
static   int samples[NMIX];
// If -1, do nothing special. if >= 0, for that many samples, continue
// making the current sound, decreasing it in volume and decreasing fades,
// until reaching -1, and then set the instrument to NONE and volume to 0.
static   int fades[NMIX];

#define NBANDS 8
static   int oldpass[NMIX][NBANDS];

double effect;
// #define EFFECT_FREQ(f) (((f) * (1.0 + (0.059463094359 * effect))))
#define EFFECT_FREQ(f) (f)
// #define EFFECT_POST(s) (s)

static const int decimate_masks[] = {
  0x0000,
  0x0001,
  0x0003,
  0x0007,
  0x000F,
  0x001F,
  0x003F,
  0x007F,
  0x00FF,
  0x00FF,
  0x01FF,
  0x03FF,
  0x07FF,
  0x0FFF,
  0x1FFF,
  0x3FFF,
  0x7FFF,
  0xFFFF,
};
// #define EFFECT_POST(s) ( (Sint16) ( ((s) >> (int)(effect * 15.0)) << (int)(effect * 15.0) ) )
// for some reason this gets real loud when at max?
// #define EFFECT_POST(s) (((s + 32768) & ~decimate_masks[(int)(effect * 15.0)]) - 32768)

#define EFFECT_POST(s) ( ((ctr % (1 + (int)(effect * 32.0))))?last_sample:(s) )

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
  int i, ch;
  static int seed;
  static int last_sample, ctr;

  /* length is actually in bytes; halve it */
  len >>= 1;
  for(i = 0; i < len; i ++) {
    int mag = 0;
    ctr++;

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
        double cycle = (((double)RATE * HZFACTOR) / EFFECT_FREQ(cur_freq[ch]) );
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
        double cycle = (((double)RATE * HZFACTOR) / EFFECT_FREQ(cur_freq[ch]));
        double pos = fmod(samples[ch], cycle);
        /* sweeping from -vol to +vol with period 'cycle' */
        mag += -cur_vol[ch] + (int)( (pos / cycle) * 2.0 * cur_vol[ch] );

        break;
      }
      case INST_SQUARE: {
        samples[ch] ++;
        /* the frequency is the number of cycles per HZFACTOR seconds.
           so the length of one cycle in samples is (RATE*HZFACTOR)/cur_freq.

           PERF: fmod is pretty slow and it is easy to make square
           waves with other means.
        */
        double cycle = (((double)RATE * HZFACTOR) / EFFECT_FREQ(cur_freq[ch]));
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
            if (EFFECT_FREQ(cur_freq[ch]) < freq) {
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
          fprintf(stderr,
                  "Instrument %d unknown (or sample %d out of range)\n",
                  cur_inst[ch], w);
          abort();
        } else {
          int waveindex = sets[w][cur_freq[ch]];
          if (waveindex >= num_waves ||
              waveindex < 0) {
            fprintf(stderr, "Wave in sampler bay is balls: %d\n", waveindex);
            abort();
          }
          if (samples[ch] < waves[sets[w][cur_freq[ch]]].nsamples) {
            // Now takes channel volume into account (used to be just 0.5 before 2015).
            mag += waves[waveindex].samples[samples[ch]] * (cur_vol[ch] * (MAX_VOL_INVF * 2.0f));
            samples[ch]++;
          }
        }
      }
      }
    }
    /* PERF clipping seems to happen automatically in the cast? */
    if (mag > MAX_MIX) mag = MAX_MIX;
    else if (mag < MIN_MIX) mag = MIN_MIX;

    last_sample = stream[i] = (Sint16) EFFECT_POST(mag);
  }
}

/* PERF: Might be safe to only lock for certain kinds of changes (like
   to the sampler) that have bad data race issues. Not locking would
   improve performance and also latency for in-frame frequency
   changes. However, it's not clear what memory model is in play here
   (might an update change half a word at a time, creating weird
   glitches?). Let us be proper.  (Atomics??  -tom7  14 Nov 2015)
*/
void ml_setfreq(int ch, int nf, int nv, int inst) {
  SDL_LockAudio();

  // if (inst < SAMPLER_OFFSET) nf += effect * nf; // XXXX
#if 0
  if (ch < 11 /* && inst >= SAMPLER_OFFSET */) { // || inst != INST_NONE) {
    printf("(cur inst: %d) Set %d = %d (Hz/10000) %d %d\n",
           cur_inst[ch], ch, nf, nv, inst);
      //      if (nf < HZFACTOR * 2000) printf ("BANDPASS.");
    }
#endif

  if ((nv == 0 || inst == INST_NONE) &&
      (cur_inst[ch] == INST_SINE || cur_inst[ch] == INST_RHODES)) {

    // printf("Made ch %d start fading\n", ch);
    // set fadeout samples.
    fades[ch] = ENV_FADEOUT_SAMPLES;

  } else {
    cur_vol[ch] = (int)(VOL_FACTOR * (float)nv);

    // if (inst >= SAMPLER_OFFSET) {
    //   printf("Set sample vol for ch %d to %d\n", ch, cur_vol[ch]);
    // }

    // Without lock, this can put the sampler wave way out of
    // the range of the array.
    cur_freq[ch] = nf;
    cur_inst[ch] = inst;
    fades[ch] = -1;

    if (inst >= SAMPLER_OFFSET) {
      if (nf >= 128 || nf < 0) {
        fprintf(stderr, "Sampler wave %d out of gamut\n", nf);
        abort();
      }
    }

    if (inst == INST_NOISE) {
      int i;
      for(i = 0; i < NBANDS; i ++) oldpass[ch][i] = 0;
    } else {
      samples[ch] = 0;
    }
  }
  SDL_UnlockAudio();
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
  if (SDL_OpenAudio(&fmt, &got) < 0) {
    fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
    exit(1);
  }

  fprintf(stderr, "Audio data: %d samples, %d channels, %d rate\n",
          got.samples, got.channels, got.freq);

  SDL_PauseAudio(0);
}

int ml_sampleroffset () {
  return SAMPLER_OFFSET;
}

int ml_total_mix_channels () {
  return NMIX;
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
  } else if (num_sets >= MAX_SETS) {
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

void ml_seteffect (double r) {
  if (r < 0.0) r = 0.0;
  else if (r > 1.0) r = 1.0;
  effect = r;
}

void ml_writeword (FILE * f, int w) {
  fwrite(&w, sizeof(int), 1, f);
}

void ml_fseek (FILE * f, int offset) {
  fseek(f, offset, SEEK_SET);
}


// You might want to disable all of this junk,
// since it is for proprietary one-off hardware
// that you probably don't have.
#ifdef WIN32
#include <windows.h>

HANDLE wombfile = INVALID_HANDLE_VALUE;
// XXX consider VirtualAlloc for alignment.
char wombsector[512] = {0};

int ml_openwomb () {
  // magic words to signal a command
  wombsector[0] = 'w';
  wombsector[1] = 'o';
  wombsector[2] = 'm';
  wombsector[3] = 'b';
  wombfile = CreateFile("i:\\FILE.TXT",
                        GENERIC_READ | GENERIC_WRITE,
                        /* Sharing */
                        FILE_SHARE_READ | FILE_SHARE_WRITE,
                        /* Useless security thing */
                        NULL,
                        /* Don't create it */
                        OPEN_EXISTING,
                        /* probably ignored since the file exists */
                        FILE_ATTRIBUTE_NORMAL |
                        /* but want to not buffer (XXX makes alignment restrictions?). */
                        FILE_FLAG_NO_BUFFERING |
                        /* immediate writes. */
                        // FILE_FLAG_WRITE_THROUGH
                        0,
                        /* template file, ignored because exists. */
                        NULL);
  return wombfile != INVALID_HANDLE_VALUE;
}

int ml_signal (int w) {
  if (wombfile != INVALID_HANDLE_VALUE) {
    // write command data.
    wombsector[4] = (w >> 24) & 255;
    wombsector[5] = (w >> 16) & 255;
    wombsector[6] = (w >>  8) & 255;
    wombsector[7] = (w >>  0) & 255;
    DWORD written;
    // CancelIO(wombfile);
    if (SetFilePointer(wombfile, 0, 0, FILE_BEGIN) == INVALID_SET_FILE_POINTER) {
      printf("SEEK FAILED.\n");
    }
    if (!WriteFile(wombfile,
                   wombsector,
                   (DWORD)(sizeof(wombsector)),
                   &written,
                   NULL)) {
      printf("WRITEFILE FAILED.\n");
      DWORD dw = GetLastError();
      LPVOID message;
      FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER |
                    FORMAT_MESSAGE_FROM_SYSTEM |
                    FORMAT_MESSAGE_IGNORE_INSERTS,
                    NULL,
                    dw,
                    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                    (LPTSTR) &message,
                    0, NULL);

      printf(" ... %s\n", message);
    }
  }
}

#else // not WIN32

#if 0
// Totally sux on OS X; doesn't do any writes until
// the file is CLOSED!

FILE * womb = NULL;
char wombsector[16] = {0};
int ml_openwomb() {
  womb = fopen("/Volumes/Drive Name/FILE.TXT", "wb");
  if (womb) {
    setbuf(womb, NULL);
    wombsector[0] = 'w';
    wombsector[1] = 'o';
    wombsector[2] = 'm';
    wombsector[3] = 'b';
  }
  return !!womb;
}

void ml_signal(int w) {
  if (womb != NULL) {
    wombsector[4] = (w >> 24) & 255;
    wombsector[5] = (w >> 16) & 255;
    wombsector[6] = (w >>  8) & 255;
    wombsector[7] = (w >>  0) & 255;
    fseek(womb, 0, SEEK_SET);
    fwrite(&wombsector, sizeof(wombsector), 1, womb);
    fflush(womb);
  }
}
#endif

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <fcntl.h>

int wombfd = 0;
char wombsector[512] = {0};
int ml_openwomb() {
  wombfd = open("/Volumes/Drive Name/FILE.TXT", O_RDWR);
  if (wombfd > 0) {
    // XXX fnctls...
    fcntl(wombfd, F_NOCACHE, 1);
    // fcntl(wombfd, F_SETFL, O_NONBLOCK);
    wombsector[0] = 'w';
    wombsector[1] = 'o';
    wombsector[2] = 'm';
    wombsector[3] = 'b';
  }
  return wombfd > 0;
}

void ml_signal(int w) {
  if (wombfd != 0) {
    wombsector[4] = (w >> 24) & 255;
    wombsector[5] = (w >> 16) & 255;
    wombsector[6] = (w >>  8) & 255;
    wombsector[7] = (w >>  0) & 255;
    // XXX consider pwrite, which takes offset
    // lseek(wombfd, 0, SEEK_SET);
    if (sizeof(wombsector) !=
        //      write(wombfd, &wombsector, sizeof(wombsector))) {
        pwrite(wombfd, &wombsector, sizeof(wombsector), 0)) {
      printf("write failed.\n");
    }
    // fcntl(wombfd, F_FULLFSYNC);
    fsync(wombfd);
  }
}


/*
// always fail.
int ml_openwomb() { return 0; }
void ml_signal(int w) { }
*/

#endif  // otherwise..
