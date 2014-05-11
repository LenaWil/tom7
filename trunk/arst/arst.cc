
#include "arst.h"

#include <stdio.h>
#include <utility>

#include "sdlutil-lite.h"
#include "time.h"
#include "SDL.h"
#include "SDL_main.h"
#include "../cc-lib/util.h"
#include "../cc-lib/stb_image.h"
#include "chars.h"
#include "font.h"
#include "script.h"

// original file size
#define FRAMEWIDTH 480
#define FRAMEHEIGHT 270
// XXX more like 200k
// filenames are 0 - (NUM_FRAMES - 1)
#define NUM_FRAMES 179633
// #define NUM_FRAMES 50000

#define SCRIPTWIDTH 800

#define EXTRAHEIGHT 400

#define WORDX 20
#define WORDY 380

// XXX add UI
#define WIDTH (FRAMEWIDTH * 2) + SCRIPTWIDTH
#define HEIGHT (FRAMEHEIGHT * 2) + EXTRAHEIGHT

#define SWAB 1

// Smaller is better here.
#define SAMPLES_PER_BUF 512 // 4096
// #define FPS 23.976
#define FPS 24.000
#define MS_PER_FRAME (1000.0 / FPS)
#define AUDIO_SAMPLERATE 48000
#define SAMPLES_PER_FRAME (AUDIO_SAMPLERATE / (double)FPS)
#define FRAMES_PER_SAMPLE (1 / SAMPLES_PER_FRAME)

#define BYTES_PER_AUDIO_SAMPLE 2
#define AUDIO_CHANNELS 2

#define AUDIO "d:\\video\\starwars.wav"
#define SCRIPTFILE "starwars.txt"

SDL_Surface *screen = 0;

static string FrameFilename(int f) {
  return StringPrintf("d:\\video\\starwars_quarterframes\\s%06d.jpg", f);
}

struct Frame {
  // Store compressed frames.
  vector<uint8> bytes;
};

// Global for easier thread access.
static vector<Frame> frames;
static void InitializeFrames() {
  frames.resize(NUM_FRAMES);  
}

// Sound 
static Uint32 audio_length;
static Uint8 *movie_audio;
static SDL_AudioSpec audio_spec;

// T must be copyable.
template<class T>
T AtomicRead(T *loc, SDL_mutex *m) {
  SDL_LockMutex(m);
  T val = *loc;
  SDL_UnlockMutex(m);
  return val;
}

template<class T>
void AtomicWrite(T *loc, T value, SDL_mutex *m) {
  SDL_LockMutex(m);
  *loc = value;
  SDL_UnlockMutex(m);
}

SDL_mutex *audio_mutex;
static int currentsample = 0;
static bool playing = true;
static int seek_to_sample = -1;

static void Pause() {
  AtomicWrite(&playing, false, audio_mutex);
}

static void Play() {
  AtomicWrite(&playing, true, audio_mutex);
}

static void TogglePause() {
  SDL_LockMutex(audio_mutex);
  playing = !playing;
  SDL_UnlockMutex(audio_mutex);
}

static void Seek(int sample) {
  AtomicWrite(&seek_to_sample, sample, audio_mutex);
}

static void SeekFrame(int frame) {
  Seek(frame * SAMPLES_PER_FRAME);
}

// This thing needs to know what frame we're looking at.
void AudioCallback(void *userdata, Uint8 *stream, int len) {
  // Maybe get a signal from elsewhere that we should seek
  // to some sample offset.
  SDL_LockMutex(audio_mutex);
  if (seek_to_sample >= 0) {
    currentsample = seek_to_sample;
    seek_to_sample = -1;
  }
  int sampleidx = currentsample;
  bool lplaying = playing;  
  // Advance this while we hold the mutex.
  if (lplaying) {
    currentsample += SAMPLES_PER_BUF;
  }
  SDL_UnlockMutex(audio_mutex);

  if (len != AUDIO_CHANNELS * BYTES_PER_AUDIO_SAMPLE * SAMPLES_PER_BUF) {
    printf("len %d  ac %d bpas %d spb %d\n", 
	   len, 
	   AUDIO_CHANNELS,
	   BYTES_PER_AUDIO_SAMPLE,
	   SAMPLES_PER_BUF);
    abort();
  }
  CHECK(len == AUDIO_CHANNELS * BYTES_PER_AUDIO_SAMPLE * SAMPLES_PER_BUF);

  if (lplaying) {
    int byteidx = sampleidx * BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS;
    for (int i = 0; i < len; i++) {
      stream[i] = (byteidx + i < audio_length) ?
	movie_audio[byteidx + i] :
	0;
    }
  } else {
    // Silence.
    for (int i = 0; i < len; i++) {
      stream[i] = 0;
    }
  }
}

static void LoadOpenAudio() {
  if (SDL_LoadWAV(AUDIO, &audio_spec, &movie_audio, &audio_length) == NULL) {
    CHECK(!"unable to load audio");
  }
  CHECK(audio_spec.freq == AUDIO_SAMPLERATE);

  // needs to be one of the 16-bit types
  CHECK(BYTES_PER_AUDIO_SAMPLE == 2);
  CHECK(audio_spec.format == AUDIO_U16LSB ||
	audio_spec.format == AUDIO_S16LSB ||
	audio_spec.format == AUDIO_U16MSB ||
	audio_spec.format == AUDIO_S16MSB);

  CHECK(audio_spec.channels == AUDIO_CHANNELS);
  printf("Loaded audio.\n");
  SDL_AudioSpec want, have;
  // SDL_Zero(want);
  want.freq = audio_spec.freq;
  want.format = audio_spec.format;
  want.channels = audio_spec.channels;
  want.samples = SAMPLES_PER_BUF;
  want.callback = AudioCallback;
  if (SDL_OpenAudio(&want, &have) < 0) {
    CHECK(!"unable to open audio");
  }
  CHECK(have.freq == want.freq);
  CHECK(have.samples == SAMPLES_PER_BUF);

  printf("Audio open.\n");
  audio_mutex = SDL_CreateMutex();
  CHECK(audio_mutex);
}

static void ReadFileBytes(const string &f, vector<uint8> *out) {
  string s = Util::ReadFile(f);
  CHECK(!s.empty());
  out->clear();
  out->reserve(s.size());
  // PERF memcpy
  for (int i = 0; i < s.size(); i++) {
    out->push_back((uint8)s[i]);
  }
}

static int LoadFrameThread(void *vdata) {
  pair<int, int> *data = (pair<int, int> *)vdata;
  printf("Started LFT %d\n", data->first);
  for (int f = data->first; f < data->second; f++) {
    const string fname = FrameFilename(f);
    // printf ("... %s\n", fname.c_str());
    ReadFileBytes(fname, &frames[f].bytes);
  }
  printf("Finishing LFT %d\n", data->first);
  return 0;
}

#if 0
// assumes RGBA, surfaces exactly the same size, etc.
static void CopyRGBA(const vector<uint8> &rgba, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, &rgba[0], surface->w * surface->h * 4);
}
#endif

static void CopyRGBA2x(const vector<uint8> &rgba, SDL_Surface *surface) {
  Uint8 *p = (Uint8 *)surface->pixels;
  const int width = surface->w;
  CHECK((width & 1) == 0);
  const int halfwidth = width >> 1;
  const int height = surface->h;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int idx = (y * width + x) * 4;
      int hidx = ((y >> 1) * halfwidth + (x >> 1)) * 4;
      #if SWAB
      p[idx + 0] = rgba[hidx + 2];
      p[idx + 1] = rgba[hidx + 1];
      p[idx + 2] = rgba[hidx + 0];
      p[idx + 3] = rgba[hidx + 3];
      #else
      p[idx + 0] = rgba[hidx + 0];
      p[idx + 1] = rgba[hidx + 1];
      p[idx + 2] = rgba[hidx + 2];
      p[idx + 3] = rgba[hidx + 3];
      #endif
    }
  }
}

struct Graphic {
  // From a PNG file.
  explicit Graphic(const vector<uint8> &bytes) {
    int bpp;
    uint8 *stb_rgba = stbi_load_from_memory(&bytes[0], bytes.size(),
					    &width, &height, &bpp, 4);
    CHECK(stb_rgba);
    for (int i = 0; i < width * height * 4; i++) {
      rgba.push_back(stb_rgba[i]);
      //       if (bpp == 3 && (i % 3 == 2)) {
      // rgba.push_back(0xFF);
      //}
    }
    stbi_image_free(stb_rgba);
    if (DEBUGGING)
      fprintf(stderr, "image is %dx%d @%dbpp = %lld bytes\n",
	      width, height, bpp,
	      rgba.size());

    surf = sdlutil::makesurface(width * 2, height * 2, true);
    CHECK(surf);
    CopyRGBA2x(rgba, surf);
  }

  // to screen
  void Blit(int x, int y) {
    sdlutil::blitall(surf, screen, x, y);
  }

  ~Graphic() {
    SDL_FreeSurface(surf);
  }

  int width, height;
  vector<uint8> rgba;
  SDL_Surface *surf;
};

struct LabeledFrames {
  LabeledFrames() {
    InitializeFrames();
    LoadFrames();
    font = Font::create(screen,
			"font.png",
			FONTCHARS,
			9, 16, FONTSTYLES, 1, 3);
    fonthuge = Font::create(screen,
			    "fontmax.png",
			    FONTCHARS,
			    27 * 2, 48 * 2, FONTSTYLES, 3 * 2, 3);
    script = Script::Load(SCRIPTFILE);
  }
  
  void LoadFrames() {
    uint64 start = time(NULL);

    static const int FRAMES_PER_THREAD = 10000;
    vector< pair<int, int> > datas;
    vector<string> names;
    for (int i = 0; i < NUM_FRAMES; i += FRAMES_PER_THREAD) {
      datas.push_back(make_pair(i, min(NUM_FRAMES, i + FRAMES_PER_THREAD)));
      names.push_back("lft" + i);
    }
    printf("There will be %lld thread(s)\n", datas.size());

    vector<SDL_Thread *> threads;
    for (int i = 0; i < datas.size(); i++) {
      printf("Spawn thread %d:\n", i);
      threads.push_back(SDL_CreateThread(LoadFrameThread, 
					 // names[i].c_str(),
					 (void*)&datas[i]));
    }

    for (int i = 0; i < threads.size(); i++) {
      int ret_unused;
      SDL_WaitThread(threads[i], &ret_unused);
    }
    printf("%d frames loaded in %lld sec. Bytes used:\n", NUM_FRAMES,
	   time(NULL) - start);

    uint64 bytes_used = 0ULL;
    for (int i = 0; i < frames.size(); i++) {
      bytes_used += frames[i].bytes.size();
    }
    printf("Total bytes used: %.2fmb (%.2fk / frame)\n",
	   (bytes_used / 1000000.0),
	   (bytes_used / (double)frames.size()) / 1000.0);
  }

  void Editor () {
    LoadOpenAudio();

    SDL_PauseAudio(0);

    int displayedframe = -1;
    Uint32 lastframe = 0;

    for (;;) {
      int sample = AtomicRead(&currentsample, audio_mutex);
      int frame = FRAMES_PER_SAMPLE * sample;
      
      #if 0
      if (playing) {
	if (SDL_GetAudioStatus() == SDL_AUDIO_PAUSED) {
	  SDL_PauseAudio(0);
	}
      } else {
	if (SDL_GetAudioStatus() == SDL_AUDIO_PLAYING) {
	  SDL_PauseAudio(1);
	}
      }
      #endif

      if (frame != displayedframe) {
	lastframe = SDL_GetTicks();
	displayedframe = frame;
	Graphic g(frames[frame].bytes);
	g.Blit(0, 0);

	font->draw(0, 0,
		   StringPrintf("Frame ^1%d^< (^3%.2f%%^<)   Sample ^4%d",
				frame, (100.0 * frame) / frames.size(),
				sample));
	
	/*
	sdlutil::fillrect(screen, 0,
			  WORDX, WORDY, W, H);
	*/

	Line *line = script->GetLine(sample);
	if (line->Unknown()) {
	  fonthuge->draw(WORDX, WORDY, "^2?");
	} else if (line->s.empty()) {
	  fonthuge->draw(WORDX, WORDY, "---");
	} else {
	  fonthuge->draw(WORDX, WORDY, line->s);
	}

	SDL_Flip(screen);
      }

      // Ignore events for now
      SDL_Event event;
      if (SDL_PollEvent(&event)) {
	switch (event.type) {
	case SDL_QUIT:
	  printf("Got quit.\n");
	  return;
	case SDL_KEYDOWN:
	  // printf("Key %d\n", event.key.keysym.unicode);
	  switch(event.key.keysym.sym) {
	  default:
	    break;
	  case SDLK_ESCAPE:
	    printf("Got esc.\n");
	    return;
	  case SDLK_SPACE: {
	    TogglePause();
	    break;
	  }
	  case SDLK_COMMA:
	    Pause();
	    SeekFrame(max(0, frame - 1));
	    break;
	  case SDLK_PERIOD:
	    Pause();
	    SeekFrame(max(0, frame + 1));
	    break;

	  case SDLK_DOWN: {
	    int lidx = script->GetLineIdx(sample);
	    // printf("Down @%d.\n", lidx);
	    if (lidx + 1 < script->lines.size()) {
	      Seek(script->lines[lidx + 1].sample);
	    }
	    break;
	  }

	  case SDLK_UP: {
	    int lidx = script->GetLineIdx(sample);
	    // printf("Up @%d.\n", lidx);
	    if (lidx > 0) {
	      Seek(script->lines[lidx - 1].sample);
	    }
	    break;
	  }

	  case SDLK_LEFTBRACKET:
	    SeekFrame(max(0, frame - 1000));
	    break;
	  case SDLK_RIGHTBRACKET:
	    SeekFrame(min(frame + 1000, (int)(frames.size() - 1)));
	    break;
	  }
	}
      }

    }
  }
  
  Script *script;
  Font *font, *fonthuge;
};


int SDL_main (int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO |
		 SDL_INIT_TIMER | 
		 SDL_INIT_AUDIO) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");
  printf("Samples per frame: %f\n", SAMPLES_PER_FRAME);

  SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, 
                      SDL_DEFAULT_REPEAT_INTERVAL);

  SDL_EnableUNICODE(1);

  screen = sdlutil::makescreen(WIDTH, HEIGHT);
  CHECK(screen);

  LabeledFrames lf;
  lf.Editor();

  SDL_Quit();
  return 0;
}
