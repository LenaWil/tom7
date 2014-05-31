
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
#include "pngsave.h"

// original file size

// XXX: use full rez frames
#define FRAMEWIDTH 480
#define FRAMEHEIGHT 270
// XXX more like 200k
// filenames are 0 - (NUM_FRAMES - 1)
#define NUM_FRAMES 179633
// #define NUM_FRAMES 50000

#define WORDX 20
#define WORDY 380

// XXX add UI
#define WIDTH FRAMEWIDTH
#define HEIGHT FRAMEHEIGHT

// XXX need big-ass font
#define FONTBIGWIDTH 18
#define FONTBIGHEIGHT 32

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
#define SECONDS_PER_SAMPLE (1.0 / AUDIO_SAMPLERATE)
#define SAMPLES_PER_FRAME (AUDIO_SAMPLERATE / (double)FPS)
#define FRAMES_PER_SAMPLE (1 / SAMPLES_PER_FRAME)

#define MAX_SAMPLES_DEBUG (AUDIO_SAMPLERATE * 20)

#define BYTES_PER_AUDIO_SAMPLE 2
#define AUDIO_CHANNELS 2

#define AUDIO "d:\\video\\starwars.wav"
#define SCRIPTFILE "starwars.txt"

// Max bytes we'll use for the frame cache. Better underestimate
// because this doesn't count malloc and alignment overhead, etc.
static constexpr uint64 MAX_BYTES = 
  // kilobytes
  1024ULL *
  // megabytes
  1024ULL *
  // gigabytes
  1024ULL *
  // forty-eight gigabytes
  48ULL;

SDL_Surface *screen = 0;

static string FrameFilename(int f) {
  return StringPrintf("d:\\video\\starwars_quarterframes\\s%06d.jpg", f);
}

static string FrameOutFilename(int f) {
  return StringPrintf("d:\\video\\starwars_testout\\s%06d.jpg", f);
}

struct Graphy;
struct Frame {
  SDL_mutex *mutex;
  Graphy *graphy;
};

// Protects the number of bytes used. This variable keeps track of
// how many bytes we've currently allocated to future frames.
static SDL_mutex *bytes_mutex;
static uint64 bytes_used = 0ULL;

// Global for easier thread access.
// Don't resize after startup -- the vector itself is not protected
// and must be thread-safe.
static vector<Frame> frames;
static void InitializeFrames() {
  frames.resize(NUM_FRAMES);  
  for (int i = 0; i < frames.size(); i++) {
    frames[i].mutex = SDL_CreateMutex();
    frames[i].graphy = NULL;
  }

  AtomicWrite(&bytes_used, 0ULL, bytes_mutex);
}

// Input sound 
static Uint32 audio_length;
static int num_audio_samples;
static Uint8 *movie_audio;
static SDL_AudioSpec audio_spec;

static void LoadAudio() {
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

  {
    // Note: Logic below requires this to be integral or we get some
    // drift. It's wouldn't be that hard to make general, but it's an
    // int with 48khz and 24fps so we can do the simple thing.
    double leftover = fabs(round(SAMPLES_PER_FRAME) - SAMPLES_PER_FRAME);
    printf("Samples per frame %f (lo: %f)\n", SAMPLES_PER_FRAME, leftover);
    CHECK(leftover < 0.0000000000001);
  }

  printf("got: %d LSB (u %d s %d) MSB (u %d s %d)\n",
	 audio_spec.format,
	 AUDIO_U16LSB,
	 AUDIO_S16LSB,
	 AUDIO_U16MSB,
	 AUDIO_S16MSB);
}

Script *script;
struct Word {
  string word;
  uint64 start_sample;
  // One past last sample.
  uint64 end_sample;
};
// Don't modify.
vector<Word> sorted;
static void LoadScript() {
  script = Script::Load(num_audio_samples, SCRIPTFILE);
  // XXX: do some sample zeroing in the script.
  for (int i = 0; i < script->lines.size(); i++) {
    const Line &line = script->lines[i];
    if (line.Unknown()) {
      printf("Note: script line %d is unknown, skipped..\n", i);
    } else if (line.s.empty()) {
      // No dialogue. Skip.
    } else {
      Word w{line.s, line.sample, script->GetEnd(i)};
      sorted.push_back(w);
    }
  }

  // Now sort it.
  std::sort(sorted.begin(), sorted.end(), [](const Word &a,
					     const Word &b) {
	      // First alphabetically, then by position in movie.
	      if (a.word == b.word) {
		return a.start_sample < b.start_sample;
	      } else {
		return a.word < b.word;
	      }
	    });

  // XXX: do some sample zeroing in the script.
}

#if 0
// This thing needs to know what frame we're looking at.
void AudioCallback(void *userdata, Uint8 *stream, int len) {
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
#endif

#if 0
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
#endif

struct Graphy {
  // From a PNG filename.
  explicit Graphy(const string &filename) {
    int width, height, bpp;
    uint8 *stb_rgba = stbi_load(filename.c_str(),
				&width, &height, &bpp, 4);
    CHECK(stb_rgba);
    vector<uint8> rgba;
    rgba.reserve(width * height * 4);
    for (int i = 0; i < width * height * 4; i++) {
      rgba.push_back(stb_rgba[i]);
    }
    stbi_image_free(stb_rgba);
    if (DEBUGGING)
      fprintf(stderr, "image is %dx%d @%dbpp = %lld bytes\n",
              width, height, bpp,
              rgba.size());

    surf = sdlutil::makesurface(width, height, true);
    CHECK(surf);
    CopyRGBA(rgba, surf);
  }

  uint64 BytesUsed() const {
    return surf->w * surf->h * 4ULL;
  }

  void BlitTo(SDL_Surface *surfto, int x, int y) {
    sdlutil::blitall(surf, surfto, x, y);
  }

  ~Graphy() {
    SDL_FreeSurface(surf);
  }

  SDL_Surface *surf;
 private:
  NOT_COPYABLE(Graphy);
};

Font *font, *fontbig, *fonthuge;

// Ensure that the frame is loaded (and rendered). THE MUTEX MUST
// BE HELD. Doesn't worry about exceeding maxbytes, but does
// increment it appropriately. f->graphy will be non-null after
// the call.
//
// Returns true if we did some work.
static bool MaybeMakeFrame(int frame_num, Frame *f) {
  if (f->graphy == NULL) {
    const string filename = FrameFilename(frame_num);
    Graphy *g = new Graphy(filename);

    int sample = frame_num * SAMPLES_PER_FRAME;
    const Line *line = script->GetLine(sample);
    if (line->Unknown()) {
      printf("Makeframe %d (sample %d) is unknown..?\n", frame_num, sample);
      // fonthuge->draw(WORDX, WORDY, "^2?");
    } else if (line->s.empty()) {
      printf("Makeframe %d (sample %d) is blank..?\n", frame_num, sample);
      // fonthuge->draw(WORDX, WORDY, "---");
    } else {
      fonthuge->drawto(g->surf, WORDX, WORDY, line->s);
    }

    // TODO: Other drawing; progress meter, word histograms, etc.

    // Account for the allocation we did.
    {
      MutexLock ml(bytes_mutex);
      bytes_used += g->BytesUsed();
    }

    f->graphy = g;
    return true;
  }
  return false;
}

struct Outputter {
  Outputter() : samples_until_frame(0), num_frames_output(0) {
    InitializeFrames();
    LoadScript();
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
    frames_i_loaded = 0;
  }

  // Given a logical sample index, get the audio data as a pair of
  // floating point numbers in [-1, 1] (left and right audio channels).
  static pair<float, float> GetAudioSample(int s) {
    const int byteidx = s * BYTES_PER_AUDIO_SAMPLE *
      AUDIO_CHANNELS;
    const float l = (1.0f / 32768.0f) * (float)
      *(Sint16*)&movie_audio[byteidx];
    const float r = (1.0f / 32768.0f) * (float)
      *(Sint16*)&movie_audio[byteidx + BYTES_PER_AUDIO_SAMPLE];
    return make_pair(l, r);
  }

  // XX Below
  vector<pair<float, float>> samples_out;

  // This is the number of samples we have until we need to output
  // another frame. We go a single sample at a time. Outputting a
  // frame gets us a budget of SAMPLES_PER_FRAME, duh.
  int samples_until_frame;
  // Number of frames we've output. 0-based.
  int num_frames_output;

  static int FrameForSample(int s) {
    return FRAMES_PER_SAMPLE * s;
  }

  int frames_i_loaded;

  // MUTEX MUST BE HELD.
  void WriteFrame(Frame *f) {
    const string outfile = FrameOutFilename(num_frames_output);
    
    CHECK(PngSave::SaveAlpha(outfile,
			     f->graphy->surf->w, f->graphy->surf->h,
			     SurfaceRGBA(f->graphy->surf)));
    // Eagerly delete! (?)
    uint64 bytes_saved = f->graphy->BytesUsed();
    delete f->graphy;
    f->graphy = NULL;
    {
      MutexLock ml(bytes_mutex);
      CHECK(bytes_used >= bytes_saved);
      bytes_used -= bytes_saved;
    }
    num_frames_output++;
  }

  void OutputSample(const Word &word, int s) {
    if (samples_until_frame == 0) {
      // We hope that the loading thread has pulled this bad boy in,
      // but if not, we'll do it here.
      int frame_num = FrameForSample(s);
      // PERF maybe count how often we block, or how much time we
      // spend waiting.
      MutexLock ml(frames[frame_num].mutex);
      if (MaybeMakeFrame(frame_num, &frames[frame_num])) {
	frames_i_loaded++;
	printf("Main thread load of #%d (%d total).\n", 
	       frame_num,
	       frames_i_loaded);
      }
     
      // PERF probably important to do this in separate threads
      // too.
      WriteFrame(&frames[frame_num]);
      samples_until_frame = SAMPLES_PER_FRAME;
    }
    pair<float, float> mag = GetAudioSample(s);
    samples_out.push_back(mag);

    // XXX
    if (samples_out.size() > MAX_SAMPLES_DEBUG) {
      printf("Early exit.\n");
      abort();
    }
  }

  void Output() {
    samples_until_frame = 0;

    // Uncompressed output samples. Frames are written to files, since
    // they are hundreds of gigabytes in total (compressed!).
    
    // We go on a word-by-word basis.

    uint64 time_start = time(NULL);
    for (int w = 0; w < sorted.size(); w++) {
      const Word &word = sorted[w];
      
      // Sample loop.
      for (int s = word.start_sample; s < word.end_sample; s++) {
	OutputSample(word, s);
      }
      double sec = time(NULL) - time_start;
      double sps = samples_out.size() / sec;
      double fps = num_frames_output / sec;
      printf("%d/%d (%.2f%%) %s   %.4f sps  %.4f fps\n", 
	     w, (int)sorted.size(),
	     (100.0 * w) / sorted.size(),
	     word.word.c_str(),
	     sps, fps);
    }    
  }

};


int SDL_main (int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO |
		 SDL_INIT_TIMER) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");
  printf("Samples per frame: %f\n", SAMPLES_PER_FRAME);

  SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, 
                      SDL_DEFAULT_REPEAT_INTERVAL);

  SDL_EnableUNICODE(1);

  screen = sdlutil::makescreen(WIDTH, HEIGHT);
  CHECK(screen);

  LoadAudio();

  Outputter o;
  o.Output();

  SDL_Quit();
  return 0;
}
