
#include "arst.h"

#include <functional>
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

#define FONTBIGWIDTH 18
#define FONTBIGHEIGHT 32

#define FONTWIDTH 9
#define FONTHEIGHT 16
#define SCRIPTX ((FRAMEWIDTH * 2) + 8)

// Smaller is better here.
#define SAMPLES_PER_BUF 512 // 4096
// #define FPS 23.976
#define FPS 24.000
#define MS_PER_FRAME (1000.0 / FPS)
#define AUDIO_SAMPLERATE 48000
#define SECONDS_PER_SAMPLE (1.0 / AUDIO_SAMPLERATE)
#define SAMPLES_PER_FRAME (AUDIO_SAMPLERATE / (double)FPS)
#define FRAMES_PER_SAMPLE (1 / SAMPLES_PER_FRAME)

#define BYTES_PER_AUDIO_SAMPLE 2
#define AUDIO_CHANNELS 2

#define AUDIO "d:\\video\\starwars.wav"
#define SCRIPTFILE "starwars.txt"
#define HISTOFILE "starwars.histo"

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
  printf("There are %d audio samples\n", num_audio_samples);

  // needs to be one of the 16-bit types
  CHECK(BYTES_PER_AUDIO_SAMPLE == 2);
  CHECK(audio_spec.format == AUDIO_U16LSB ||
	audio_spec.format == AUDIO_S16LSB ||
	audio_spec.format == AUDIO_U16MSB ||
	audio_spec.format == AUDIO_S16MSB);

  printf("got: %d LSB (u %d s %d) MSB (u %d s %d)\n",
	 audio_spec.format,
	 AUDIO_U16LSB,
	 AUDIO_S16LSB,
	 AUDIO_U16MSB,
	 AUDIO_S16MSB);

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

static vector<string> SplitWords(const string &ss) {
  string s = Util::losewhitel(ss);
  vector<string> ret;
  for (;;) {
    string tok = Util::losewhitel(Util::chop(s));
    if (tok.empty()) return ret;
    ret.push_back(tok);
  }
}

struct LabeledFrames {
  LabeledFrames() {
    InitializeFrames();
    LoadFrames();
    font = Font::create(screen,
			"font.png",
			FONTCHARS,
			FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);

    fontbig = Font::create(screen,
			   "fontbig.png",
			   FONTCHARS,
			   FONTBIGWIDTH,
			   FONTBIGHEIGHT,
			   FONTSTYLES,
			   2, 3);

    fonthuge = Font::create(screen,
			    "fontmax.png",
			    FONTCHARS,
			    27 * 2, 48 * 2, FONTSTYLES, 3 * 2, 3);
    script = Script::Load(num_audio_samples, SCRIPTFILE);
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
			0, HEIGHT - FONTBIGHEIGHT - 2, 
			WIDTH, FONTBIGHEIGHT + 2);
      fontbig->draw(0, HEIGHT - FONTBIGHEIGHT - 2,
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
				  0, HEIGHT - FONTBIGHEIGHT - 2, 
				  WIDTH, FONTBIGHEIGHT + 2);
		return start;
	      case SDLK_RETURN:
		sdlutil::fillrect(screen, 0,
				  0, HEIGHT - FONTBIGHEIGHT - 2, 
				  WIDTH, FONTBIGHEIGHT + 2);
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

  string GetMS(int seconds) {
    int mins = seconds / 60;
    int secs = seconds % 60;
    return StringPrintf("^5%d^1m^5%d^1s", mins, secs);
  }

  string GetMSPlain(double seconds) {
    int seconds_i = seconds;
    int mins = seconds_i / 60;
    if (mins == 0) {
      return StringPrintf("%0.2fs", seconds);
    } else {
      int secs = seconds_i % 60;
      return StringPrintf("%dm%ds", mins, secs);
    }
  }

  void Editor() {
    SDL_PauseAudio(0);

    int displayedframe = -1;
    Uint32 lastframe = 0;
    ScriptStats stats = script->ComputeStats();

    for (;;) {
      int sample = AtomicRead(&currentsample, audio_mutex);
      int frame = FRAMES_PER_SAMPLE * sample;
      Mode lmode = AtomicRead(&mode, audio_mutex);
      
      bool dirty = false;

      if (frame != displayedframe) {
	lastframe = SDL_GetTicks();
	displayedframe = frame;
	Graphic2x g(frames[frame].bytes);
	g.BlitTo(screen, 0, 0);

	const double TOTAL_SECONDS = frames.size() / FPS;
	int dialogue = stats.fraction_words * TOTAL_SECONDS;

	string topline =
	  StringPrintf("Frame ^1%d^< (^3%.2f%%^<)   Sample ^4%d"
		       "  Labeled ^3%.2f%%^<  Dialogue %s",
		       frame, (100.0 * frame) / frames.size(),
		       sample,
		       100.0 * stats.fraction_labeled,
		       GetMS(dialogue).c_str());
	font->draw(0, 0, topline);

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

      {
	static const int WAVE_WIDTH = FRAMEWIDTH * 2;
	const int lidx = script->GetLineIdx(sample);
	const int start = script->lines[lidx].sample;
	const int end = script->GetEnd(lidx);
	sdlutil::fillrect(screen, 0x0, 
			  0, FRAMEHEIGHT * 2,
			  WAVE_WIDTH, EXTRAHEIGHT);

	// Actual range we'll draw.
	const int extra = (end - start) / 10;
	const int range_start = max(start - extra, 0);
	const int range_end = min(end + extra, num_audio_samples);
	const double width = range_end - range_start;

	const double stride = width / WAVE_WIDTH;

	std::function<double(double)> getsample_fast = [stride](double dloc) {
	  const int sampleidx = dloc;
	  const int byteidx = sampleidx * BYTES_PER_AUDIO_SAMPLE *
	    AUDIO_CHANNELS;
	  const float val = (float)*(Sint16*)&movie_audio[byteidx];
	  return val;
	};

	std::function<double(double)> getsample_max = [stride](double dloc) {
	  // const int sampleidx = dloc;
	  float maxmag = 0.0f, maxval = 0.0f;
	  for (int i = ((int)dloc); i <= ((int) dloc + stride); i++) {
	    const int byteidx = i * BYTES_PER_AUDIO_SAMPLE *
	      AUDIO_CHANNELS;
	    const float val = (float)*(Sint16*)&movie_audio[byteidx];
	    if (val > maxmag) {
	      maxmag = val;
	      maxval = val;
	    } else if (-val > maxmag) {
	      maxmag = -val;
	      maxval = val;
	    }
	  }
	  return maxval;
	};

	std::function<double(double)> getsample = 
	  (width > 3 * AUDIO_SAMPLERATE) ?
	  getsample_fast : getsample_max;

	// PERF choose the fast version if the loop is more
	// than a few seconds.

	// Get max magnitude.
	float maxmag = 0.0f;
	{
	  double dloc = range_start;
	  for (int x = 0; x < WAVE_WIDTH; x++) {
	    const float val = getsample(dloc);
	    if (val > maxmag) maxmag = val;
	    else if (-val > maxmag) maxmag = -val;
	    dloc += stride;
	  }
	}

	// In case every sample will be 0, then just a flat line.
	// We want to avoid 0/0s.
	if (maxmag == 0.0f) maxmag = 32769.0f;

	double dloc = range_start;
	for (int x = 0; x < WAVE_WIDTH; x++) {
	  const float val = getsample(dloc);
	  const float norm = val / maxmag;
	  if (norm > 1.0f || norm < -1.0f) {
	    printf("norm %f val %f maxmag %f\n", norm, val, maxmag);
	    CHECK(!"no");
	  }
	  // CHECK(norm <= 1.0f && norm >= -1.0f);

	  // draw two pixels, at y and y+1.
	  const float f = norm * 100.0; // 327.68f;
	  const int yy = (int)f;
	  const float leftover = f - yy;
	  const Uint8 byte = leftover * 0xFF;
	  const int y = FRAMEHEIGHT * 2 + (EXTRAHEIGHT >> 1) + yy;
	  // y += yy; // (val / 327.68);
	  int r1 = 0x0, r2 = 0x0, g1 = 0x0, g2 = 0x0, b = 0x0;
	  
	  if (dloc >= start && dloc <= end) {
	    g1 = byte;
	    g2 = (0xFF - byte);
	  } else {
	    r1 = byte;
	    r2 = (0xFF - byte);
	  }
	    
	  sdlutil::drawpixel(screen, x, y,
			     r1, g1, b);
	  sdlutil::drawpixel(screen, x, y + 1,
			     r2, g2, b);

	  dloc += stride;
	}
      }

      // PERF don't always draw script at right.
      // TODO: draw background for selected
      {
	sdlutil::fillrect(screen, 0, SCRIPTX, 0,
			  WIDTH - SCRIPTX,
			  HEIGHT);
	static const int NUM_LINES = 60;
	int lidx = script->GetLineIdx(sample);
	int startidx = max(0, lidx - (NUM_LINES >> 1));
	for (int i = 0; 
	     i < NUM_LINES && (startidx + i) < script->lines.size();
	     i++) {
	  const Line &line = script->lines[startidx + i];
	  string s =
	    line.Unknown() ?
	    ("*  " + GetMS(script->GetSize(startidx + i) * 
			   SECONDS_PER_SAMPLE)) :
	    line.s;
	  
	  const char *numcolor =
	    (startidx + i) == lidx ?
	    WHITE :
	    line.Unknown() ? RED : GREY;

	  font->draw(SCRIPTX, i * FONTHEIGHT,
		     StringPrintf("%s%010d  %s%s",
				  numcolor,
				  line.sample,
				  (startidx + i) == lidx ? YELLOW : 
				  (line.Unknown() ? RED : WHITE),
				  s.c_str()));
	}
	dirty = true;
      }

      if (dirty) {
	SDL_Flip(screen);
      }

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
	    case SDLK_h:
	      Histogram();
	      break;
	    case SDLK_s:
	      Save();
	      stats = script->ComputeStats();
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
	      
	      vector<string> words = SplitWords(s);
	      if (words.size() == 0) {
		script->lines[lidx].s = "";
	      } else if (words.size() == 1) {
		script->lines[lidx].s = words[0];
	      } else {
		// if s has spaces, split the current
		// interval evenly.
		int current_start =
		  script->lines[lidx].sample;
		int next_start =
		  (lidx + 1 < script->lines.size()) ?
		  script->lines[lidx + 1].sample :
		  num_audio_samples;
		int len = next_start - current_start;
		CHECK(len > 0);
		if (len < words.size() * 10) {
		  printf("Can't split -- ival too short at %d samples\n",
			 len);
		} else {
		  script->lines[lidx].s = words[0];
		  for (int i = 1; i < words.size(); i++) {
		    int mark = current_start + 
		      (i / (double)words.size()) * len;
		    printf("Mark: %d <- %s\n", mark, words[i].c_str());
		    // Should always work because we checked above.
		    CHECK(script->Split(mark));
		    Line *line = script->GetLine(mark);
		    line->s = words[i];
		  }
		}
	      }
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

	    case SDLK_QUOTE: {
	      for (int lidx = script->GetLineIdx(sample) + 1;
		   lidx < script->lines.size(); lidx++) {
		if (script->lines[lidx].Unknown()) {
		  Seek(script->lines[lidx].sample);
		  break;
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

  void Histogram() {
    map<string, pair<int, int>> histo = script->GetHistogram();
    string out;
    for (map<string, pair<int, int>>::const_iterator it = histo.begin();
	 it != histo.end();
	 ++it) {
      int num = it->second.first;
      double sec = it->second.second * SECONDS_PER_SAMPLE;
      double secperword = sec / num;
      string line = StringPrintf("%s\t%d\t%s\t%s\n", it->first.c_str(),
				 num,
				 GetMSPlain(sec).c_str(),
				 GetMSPlain(secperword).c_str());
      out += line;
    }
    Util::WriteFile(HISTOFILE, out);
    // printf("%s\n", out.c_str());
    printf("Wrote " HISTOFILE "\n");
  }
  
  Script *script;
  Font *font, *fontbig, *fonthuge;
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

  LoadOpenAudio();

  LabeledFrames lf;
  lf.Editor();

  SDL_Quit();
  return 0;
}
