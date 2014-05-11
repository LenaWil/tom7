
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
#define WIDTH ((FRAMEWIDTH * 2) + SCRIPTWIDTH)
#define HEIGHT ((FRAMEHEIGHT * 2) + EXTRAHEIGHT)

#define FONTWIDTH 9
#define FONTHEIGHT 16
#define SCRIPTX ((FRAMEWIDTH * 2) + 8)

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
static int num_audio_samples;
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

struct MutexLock {
  explicit MutexLock(SDL_mutex *m) : m(m) { SDL_LockMutex(m); }
  ~MutexLock() { SDL_UnlockMutex(m); }
  SDL_mutex *m;
};

enum Mode {
  PAUSED,
  PLAYING,
  LOOPING,
};

SDL_mutex *audio_mutex;
static int currentsample = 0;
static Mode mode = PLAYING;
static int seek_to_sample = -1;
static int currentloopoffset = 0;
static int loopstart = 0, looplen = 1;

static void Pause() {
  AtomicWrite(&mode, PAUSED, audio_mutex);
}

static void Play() {
  AtomicWrite(&mode, PLAYING, audio_mutex);
}

static void LoopMode(int lstart, int llen) {
  MutexLock ml(audio_mutex);
  mode = LOOPING;
  currentloopoffset = 0;
  loopstart = lstart;
  looplen = llen;
  CHECK(llen > 0);
  printf("LoopMode: %d for %d\n", lstart, llen);

  int byteidx = (loopstart + (looplen - 1)) * BYTES_PER_AUDIO_SAMPLE * 
    AUDIO_CHANNELS;
  CHECK(byteidx < audio_length);
}

static void TogglePause() {
  MutexLock ml(audio_mutex);
  switch (mode) {
  case LOOPING: mode = PLAYING; break;
  case PAUSED: mode = PLAYING; break;
  case PLAYING: mode = PAUSED; break;
  }
}

static void Seek(int sample) {
  AtomicWrite(&seek_to_sample, sample, audio_mutex);
}

static void SeekFrame(int frame) {
  Seek(frame * SAMPLES_PER_FRAME);
}

// This thing needs to know what frame we're looking at.
void AudioCallback(void *userdata, Uint8 *stream, int len) {
  #if 0
  if (len != AUDIO_CHANNELS * BYTES_PER_AUDIO_SAMPLE * SAMPLES_PER_BUF) {
    printf("len %d  ac %d bpas %d spb %d\n", 
	   len, 
	   AUDIO_CHANNELS,
	   BYTES_PER_AUDIO_SAMPLE,
	   SAMPLES_PER_BUF);
    abort();
  }
  #endif
  CHECK(len == AUDIO_CHANNELS * BYTES_PER_AUDIO_SAMPLE * SAMPLES_PER_BUF);

  // Maybe get a signal from elsewhere that we should seek
  // to some sample offset.
  SDL_LockMutex(audio_mutex);
  if (seek_to_sample >= 0) {
    currentsample = seek_to_sample;
    seek_to_sample = -1;
  }

  // NOTE: Need to unlock the mutex as soon as we're ready in each branch.
  switch (mode) {
    case PLAYING: {
      int sampleidx = currentsample;
      currentsample += SAMPLES_PER_BUF;
      SDL_UnlockMutex(audio_mutex);
      int byteidx = sampleidx * BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS;
      for (int i = 0; i < len; i++) {
	stream[i] = (byteidx + i < audio_length) ?
	  movie_audio[byteidx + i] :
	  0;
      }
      break;
    }

    case LOOPING: {
      CHECK(looplen > 0);
      int startloopoffset = currentloopoffset;
      currentsample = loopstart + currentloopoffset;
      currentloopoffset += SAMPLES_PER_BUF;
      currentloopoffset %= looplen;
      SDL_UnlockMutex(audio_mutex);

      int sample_len = len / (BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS);
      CHECK(sample_len * BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS == len);
      for (int i = 0; i < sample_len; i++) {
	int offset = (startloopoffset + i) % looplen;
	int byteidx = (loopstart + offset) * BYTES_PER_AUDIO_SAMPLE *
	  AUDIO_CHANNELS;
	for (int j = 0; j < BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS; j++) {
	  stream[(i * BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS) + j] =
	    movie_audio[byteidx + j];
	}
      }
      break;
    }

    case PAUSED: {
     SDL_UnlockMutex(audio_mutex);
     // play silence.
     for (int i = 0; i < len; i++) {
       stream[i] = 0;
     }
     break;
    }
  }
}

static void LoadOpenAudio() {
  if (SDL_LoadWAV(AUDIO, &audio_spec, &movie_audio, &audio_length) == NULL) {
    CHECK(!"unable to load audio");
  }
  num_audio_samples = audio_length / (BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS);
  CHECK(num_audio_samples * BYTES_PER_AUDIO_SAMPLE * AUDIO_CHANNELS ==
	audio_length);
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
			FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);
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

  void LoopAt(int lidx) {
    int start = script->lines[lidx].sample;
    int last = (lidx + 1 < script->lines.size()) ?
      script->lines[lidx + 1].sample :
      num_audio_samples;
    LoopMode(start, last - start);
  }

  int GetDelta(bool forward, int modifiers) {
    int delta = forward ? 1 : -1;
    
    // Default is to jump by frames, unless holding ctrl,
    // which means jump by 100 samples.
    if (modifiers & KMOD_CTRL) {
      delta *= 100;
    } else {
      delta *= SAMPLES_PER_FRAME;
    }
    if (modifiers & KMOD_SHIFT) {
      delta *= 10;
    }
    return delta;
  }

  // XXX would be prettier if we just edited it in the script view.
  string Prompt(const string &start) {
    string input = start;
    for (;;) {
      SDL_Delay(1);
      sdlutil::fillrect(screen, 0,
			0, HEIGHT - FONTHEIGHT - 2, WIDTH, FONTHEIGHT + 2);
      font->draw(0, HEIGHT - FONTHEIGHT - 2,
		 StringPrintf(YELLOW "? " POP "%s" YELLOW "_",
			      input.c_str()));
      SDL_Flip(screen);

      SDL_Event event;
      if (SDL_PollEvent(&event)) {
	switch (event.type) {
	  case SDL_QUIT:
	    exit(0);
	    return "";
	  case SDL_KEYDOWN: {
	    switch(event.key.keysym.sym) {
	      case SDLK_ESCAPE:
		sdlutil::fillrect(screen, 0,
				  0, HEIGHT - FONTHEIGHT - 2, 
				  WIDTH, FONTHEIGHT + 2);
		return start;
	      case SDLK_RETURN:
		sdlutil::fillrect(screen, 0,
				  0, HEIGHT - FONTHEIGHT - 2, 
				  WIDTH, FONTHEIGHT + 2);
		return input;
	      case SDLK_BACKSPACE:
		if (input.size() > 0) {
		  input = input.substr(0, input.size() - 1);
		}
		break;
	      default: {
		int uc = event.key.keysym.unicode;
		if ((uc & 0xFF80) == 0) {
		  char ch = uc & 0x7F;
		  if (ch) {
		    input += ch;
		  }
		}
	      }
	    }
	  }
	}
      }
    }
  }

  void Editor() {
    LoadOpenAudio();

    SDL_PauseAudio(0);

    int displayedframe = -1;
    Uint32 lastframe = 0;

    for (;;) {
      int sample = AtomicRead(&currentsample, audio_mutex);
      int frame = FRAMES_PER_SAMPLE * sample;
      Mode lmode = AtomicRead(&mode, audio_mutex);
      
      bool dirty = false;

      if (frame != displayedframe) {
	lastframe = SDL_GetTicks();
	displayedframe = frame;
	Graphic g(frames[frame].bytes);
	g.Blit(0, 0);

	font->draw(0, 0,
		   StringPrintf("Frame ^1%d^< (^3%.2f%%^<)   Sample ^4%d",
				frame, (100.0 * frame) / frames.size(),
				sample));

	Line *line = script->GetLine(sample);
	if (line->Unknown()) {
	  fonthuge->draw(WORDX, WORDY, "^2?");
	} else if (line->s.empty()) {
	  fonthuge->draw(WORDX, WORDY, "---");
	} else {
	  fonthuge->draw(WORDX, WORDY, line->s);
	}

	dirty = true;
      }

      // PERF don't always draw script at right.
      // TODO: draw background for selected
      {
	sdlutil::fillrect(screen, 0, SCRIPTX, 0,
			  WIDTH - SCRIPTX,
			  HEIGHT);
	static const int NUM_LINES = 50;
	int lidx = script->GetLineIdx(sample);
	int startidx = max(0, lidx - (NUM_LINES >> 1));
	for (int i = 0; 
	     i < NUM_LINES && (startidx + i) < script->lines.size();
	     i++) {
	  const Line &line = script->lines[startidx + i];
	  font->draw(SCRIPTX, i * FONTHEIGHT,
		     StringPrintf("%s%010d  %s%s",
				  (startidx + i) == lidx ? WHITE : GREY,
				  line.sample,
				  (startidx + i) == lidx ? YELLOW : WHITE,
				  line.s.c_str()));
	}
	dirty = true;
      }

      if (dirty) {
	SDL_Flip(screen);
      }

      // Ignore events for now
      SDL_Event event;
      if (SDL_PollEvent(&event)) {
	switch (event.type) {
	  case SDL_QUIT:
	    printf("Got quit.\n");
	    return;
	  case SDL_KEYDOWN: {
	    bool handledkey = false;
	    if (lmode == LOOPING) {
	      switch(event.key.keysym.sym) {
		case SDLK_h:
		case SDLK_j: {
		  handledkey = true;
		  int lidx = script->GetLineIdx(sample);
		  // Can't move start of first one.
		  if (lidx == 0) break;
		  int delta = 
		    GetDelta(event.key.keysym.sym == SDLK_j,
			     event.key.keysym.mod);
		  // Now move it, but keep it in bounds.
		  int nsample = script->lines[lidx].sample + delta;
		  // Can't touch the previous line.
		  nsample = max(script->lines[lidx - 1].sample + 1,
				nsample);
		  // Or the next one.
		  int next = (lidx + 1 < script->lines.size()) ?
		    script->lines[lidx + 1].sample :
		    num_audio_samples;
		  nsample = min(next - 1, nsample);
		  script->lines[lidx].sample = nsample;
		  // Reset loop.
		  LoopAt(lidx);
		  break;
		}

	        case SDLK_k:
	        case SDLK_l: {
		  handledkey = true;

		  int lidx = script->GetLineIdx(sample);
		  // Can't move end of last one (nothing there).
		  if (lidx == script->lines.size() - 1) break;
		  int delta = 
		    GetDelta(event.key.keysym.sym == SDLK_l,
			     event.key.keysym.mod);
		  // Now move it, but keep it in bounds.
		  int nsample = script->lines[lidx + 1].sample + delta;
		  // Can't touch the start.
		  nsample = max(script->lines[lidx].sample + 1,
				nsample);
		  // Or the next one...
		  int next = (lidx + 2 < script->lines.size()) ?
		    script->lines[lidx + 2].sample :
		    num_audio_samples;
		  nsample = min(next - 1, nsample);
		  script->lines[lidx + 1].sample = nsample;
		  // Reset loop.
		  // TODO: Would be nice if it played from like
		  // 75% of the clip, so that we hear the end
		  // right away.
		  LoopAt(lidx);
		  break;
		}

  	        default:;
	      }
	    }

	    if (handledkey) break;
	    // printf("Key %d\n", event.key.keysym.unicode);
	    switch(event.key.keysym.sym) {
	    default:
	      break;
	    case SDLK_s:
	      Save();
	      printf("Saved.\n");
	      break;
	    case SDLK_ESCAPE:
	      Save();
	      printf("Got esc.\n");
	      return;
	    case SDLK_SPACE: {
	      TogglePause();
	      break;
	    }
	    case SDLK_TAB: {
	      LoopAt(script->GetLineIdx(sample));
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

	    case SDLK_SLASH:
	      Pause();
	      script->Split(sample);
	      break;

	    case SDLK_RETURN: {
	      Pause();
	      int lidx = script->GetLineIdx(sample);
	      string s = Prompt(script->lines[lidx].s);
	      // TODO: if s has spaces, split the current
	      // interval evenly.
	      script->lines[lidx].s = s;
	      break;
	    }

	    case SDLK_DOWN: {
	      int lidx = script->GetLineIdx(sample);
	      // printf("Down @%d.\n", lidx);
	      if (lidx + 1 < script->lines.size()) {
		if (lmode == LOOPING) {
		  LoopAt(lidx + 1);
		} else {
		  Seek(script->lines[lidx + 1].sample);
		}
	      }
	      break;
	    }

	    case SDLK_UP: {
	      int lidx = script->GetLineIdx(sample);
	      // printf("Up @%d.\n", lidx);
	      if (lidx > 0) {
		if (lmode == LOOPING) {
		  LoopAt(lidx - 1);
		} else {
		  Seek(script->lines[lidx - 1].sample);
		} 
	      }
	      break;
	    }

	    case SDLK_LEFTBRACKET:
	      SeekFrame(max(0, frame - 1000));
	      if (lmode == LOOPING) Pause();
	      break;
	    case SDLK_RIGHTBRACKET:
	      SeekFrame(min(frame + 1000, (int)(frames.size() - 1)));
	      if (lmode == LOOPING) Pause();
	      break;
	    }
	  }
	}
      }

    }
  }

  void Save() {
    script->Save(SCRIPTFILE);
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
