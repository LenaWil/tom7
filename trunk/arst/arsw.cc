
#include "arst.h"

#include <functional>
#include <stdio.h>
#include <utility>
#include <deque>

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
#include "../cc-lib/wavesave.h"

// original file size
#define FRAMEWIDTH 1920
#define FRAMEHEIGHT 1080
// filenames are 0 - (NUM_FRAMES - 1)
#define NUM_FRAMES 179633

// Can set this lower if the frames are in the progres of being
// written out but you wanna get ahead.
#define MAXFULLFRAMES NUM_FRAMES
// FOX logo
#define BOGUS_FRAME 217

#define WORDX 20
#define WORDY 640

#define WIDTH FRAMEWIDTH
#define HEIGHT FRAMEHEIGHT

#define FONTBIGWIDTH 18
#define FONTBIGHEIGHT 32

#define FONTWIDTH 9
#define FONTHEIGHT 16
#define SCRIPTX ((FRAMEWIDTH * 2) + 8)

#define SWAB 1

// #define FPS 23.976
#define FPS 24.000
#define MS_PER_FRAME (1000.0 / FPS)
#define AUDIO_SAMPLERATE 48000
#define SECONDS_PER_SAMPLE (1.0 / AUDIO_SAMPLERATE)
#define SAMPLES_PER_FRAME (AUDIO_SAMPLERATE / (double)FPS)
#define FRAMES_PER_SAMPLE (1 / SAMPLES_PER_FRAME)

#define MAX_SAMPLES_DEBUG (AUDIO_SAMPLERATE * 120)

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
  // sixteen gigabytes
  16ULL;


SDL_Surface *screen = 0;

static string FrameFilename(int f) {
  return StringPrintf("d:\\video\\starwars_fullframes\\s%06d.png", f);
}

static string FrameOutFilename(int f) {
  return StringPrintf("d:\\video\\starwars_testout\\s%06d.png", f);
}

struct Graphy;
struct Frame {
  SDL_mutex *mutex;
  Graphy *graphy;
  // If graphy is non-null, the word written on it.
  string word;
};

// Protects the number of bytes used. This variable keeps track of
// how many bytes we've currently allocated to future frames.
static SDL_mutex *bytes_mutex;
static int64 bytes_used = 0ULL;

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

  AtomicWrite(&bytes_used, 0LL, bytes_mutex);
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
  int numer;
  int denom;
  uint64 start_sample;
  // One past last sample.
  uint64 end_sample;
};
// Don't modify.
vector<Word> sorted;
static int num_sorted_samples = 0;
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
      Word w{line.s, 0, 0, line.sample, script->GetEnd(i)};
      CHECK(w.end_sample > w.start_sample);
      sorted.push_back(w);
      num_sorted_samples += w.end_sample - w.start_sample;
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

  // Fill in denominators.
  map<string, int> counts;
  string lastword = "";
  int lastcount = 0;
  for (int i = 0; i < sorted.size(); i++) {
    if (lastword != sorted[i].word) {
      lastword = sorted[i].word;
      lastcount = 0;
    }
    lastcount++;
    sorted[i].numer = lastcount;
    counts[sorted[i].word]++;
  }

  for (int i = 0; i < sorted.size(); i++)
    sorted[i].denom = counts[sorted[i].word];

  // XXX: do some sample zeroing in the script.
}

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

  // Expensive, but better than doing it both on PNG load and save.
  void BlitSwab(SDL_Surface *surfto, int x, int y) {
    SDL_Surface *tmp = sdlutil::makesurface(surf->w, surf->h, true);
    const int num = surf->w * surf->h * 4;
    for (int idx = 0; idx < num; idx += 4) {
      const Uint8 *rgba = (Uint8 *)surf->pixels;
      Uint8 *p = (Uint8 *)tmp->pixels;
      #if SWAB	 
      p[idx + 0] = rgba[idx + 2];
      p[idx + 1] = rgba[idx + 1];
      p[idx + 2] = rgba[idx + 0];
      p[idx + 3] = rgba[idx + 3];
      #else
      p[idx + 0] = rgba[idx + 0];
      p[idx + 1] = rgba[idx + 1];
      p[idx + 2] = rgba[idx + 2];
      p[idx + 3] = rgba[idx + 3];
      #endif
    }
    sdlutil::blitall(tmp, surfto, x, y);
    SDL_FreeSurface(tmp);
  }

  ~Graphy() {
    SDL_FreeSurface(surf);
  }

  SDL_Surface *surf;
 private:
  NOT_COPYABLE(Graphy);
};

Font *font, *fontbig, *fonthuge, *fontmax;

static int frame_had_wrong_word = 0;

// Ensure that the frame is loaded (and rendered). THE MUTEX MUST
// BE HELD. Doesn't worry about exceeding maxbytes, but does
// increment it appropriately. f->graphy will be non-null after
// the call.
//
// Returns true if we did some work.
static bool MaybeMakeFrame(int index,
			   int frame_num, Frame *f) {
  const Word &word = sorted[index];
  if (f->graphy != NULL) {
    if (f->word == word.word) {
      return false;
    }

    frame_had_wrong_word++;
    // Wrong word! We'll have to replace it. :(
    // This should be rare, only when we need to use a frame that
    // spans two words twice while in cache.
    {
      MutexLock ml(bytes_mutex);
      bytes_used -= f->graphy->BytesUsed();
    }
    delete f->graphy;
    f->graphy = NULL;
    f->word.clear();
    // Now we'll fall through to the condition below.
  }

  if (f->graphy == NULL) {
    const string filename = 
      (frame_num < MAXFULLFRAMES) ? FrameFilename(frame_num) :
      FrameFilename(BOGUS_FRAME);
    Graphy *g = new Graphy(filename);

    fontmax->drawto(g->surf, WORDX, WORDY, word.word);
    fonthuge->drawto(g->surf, WORDX, WORDY + 48 * 2 * 2 - 16, 
		     StringPrintf("^4%d^2/^4%d", word.numer, word.denom));
    f->word = word.word;

    // Draw histogram.
    {
      int x = 0, y = 0;
      string *lastword = NULL;
      for (int i = 0; i < sorted.size(); i++) {
	Uint32 rgba = index == i ?
	  0xFFFFFFFF :
	  ((i < index) ?
	   0xFF00aa00 :
	   0xFF0077FF);
	if (x < WIDTH && y < HEIGHT) {
	  sdlutil::setpixel(g->surf, x + 216/2, HEIGHT - 1 - y, rgba);
	}
	if (lastword && *lastword == sorted[i].word) {
	  if (y < 132) {
	    y++;
	  } else {
	    y = 0;
	    x++;
	  }
	} else {
	  x++;
	  y = 0;
	  lastword = &sorted[i].word;
	} 
      }
    }

    // TODO: Other drawing; progress meter, word histograms, etc.

    // Account for the allocation we did. Note that this can go
    // over bytes_used, either because we forced this frame in
    // the main thread, or because we are holding on to some slop
    // bytes in an input thread (but it will return the balance
    // momentarily).
    {
      MutexLock ml(bytes_mutex);
      bytes_used += g->BytesUsed();
    }

    f->graphy = g;
    return true;
  }
  return false;
}

static string GetMSPlain(double seconds) {
  int seconds_i = seconds;
  int mins = seconds_i / 60;
  if (mins == 0) {
    return StringPrintf("%0.2fs", seconds);
  } else {
    int secs = seconds_i % 60;
    return StringPrintf("%dm%ds", mins, secs);
  }
}

namespace {
struct OutputQueueItem {
  int framenum;
  int w, h;
  vector<uint8> rgba;
  // Size of original data for cache accounting; should be about the
  // size of rgba.
  uint64 bytes;
};
}
static SDL_mutex *output_mutex;
static bool output_thread_should_die = false;
static deque<OutputQueueItem *> output_queue;

// Background thread that processes the output queue by writing
// the items to disk when they're available. OK to have multiple
// copies of this thread.
static int ProcessOutputItemsThread(void *) {
  for (;;) {
    SDL_LockMutex(output_mutex);
    if (output_thread_should_die) {
      SDL_UnlockMutex(output_mutex);
      return 0;
    }

    if (!output_queue.empty()) {
      OutputQueueItem *oqi = output_queue.front();
      output_queue.pop_front();

      // Now we have exclusive access to oqi and some work to do.
      // Let others touch the deque.
      SDL_UnlockMutex(output_mutex);
      const string outfile = FrameOutFilename(oqi->framenum);
      CHECK(PngSave::SaveAlpha(outfile,
			       oqi->w, oqi->h,
			       &oqi->rgba[0]));

      // Now release the memory to the cache.
      {
	MutexLock ml(bytes_mutex);
	CHECK(oqi->bytes <= bytes_used);
	bytes_used -= oqi->bytes;
      }

    } else {
      // Release it so that it can be populated...
      SDL_UnlockMutex(output_mutex);
      // ... but don't spin-lock if starved.
      SDL_Delay(5);
    }
  }
}

// MUTEX MUST BE HELD.
static void WriteFrameInBackgroundAndUnlock(Frame *f, int framenum) {
  OutputQueueItem *oqi = new OutputQueueItem;
  oqi->framenum = framenum;
  oqi->w = f->graphy->surf->w;
  oqi->h = f->graphy->surf->h;
  oqi->bytes = f->graphy->BytesUsed();
  UncopyRGBA(f->graphy->surf, &oqi->rgba);
  {
    // Only the queue update needs to be exclusive.
    MutexLock ml(output_mutex);
    output_queue.push_back(oqi);
  }

  // Now safe to eagerly delete. Save the size first.
  delete f->graphy;
  f->graphy = NULL;
  f->word.clear();
  // Done with frame.
  SDL_UnlockMutex(f->mutex);

  // Logically we release the memory from the Frame into the cache,
  // but we also allocated a copy of the same size, so we'd have
  // to add that. Instead, just don't touch it here.
}

static int FrameForSample(int s) {
  return FRAMES_PER_SAMPLE * s;
}

namespace {
struct InputQueueItem {
  // Into sorted structure.
  int index;
  int source_frame;
};
}
static SDL_mutex *input_mutex;
static bool input_thread_should_die = false;
static deque<InputQueueItem *> input_queue;

// This thing creates the work queue. Just call it once before
// starting the worker threads.
static void MakeInputFrameQueue() {
  MutexLock ml(input_mutex);
  for (int i = 0; i < sorted.size(); i++) {
    const Word &word = sorted[i];

    int s_until_frame = 0;
    // Sample loop.
    for (int s = word.start_sample; s < word.end_sample; s++) {
      if (s_until_frame == 0) {
	InputQueueItem *iqi = new InputQueueItem;
	iqi->index = i;
	iqi->source_frame = FrameForSample(s);
	input_queue.push_back(iqi);
	s_until_frame = SAMPLES_PER_FRAME;
      }
      s_until_frame--;
    }
  }
}

static int ProcessInputItemsThread(void *) {
  for (;;) {
    // First, block if we don't have enough RAM left.
    static constexpr int FRAME_SIZE_UPPERBOUND =
      (WIDTH + 100) * (HEIGHT + 100) * 4;

    int budget = 0;
    {
      MutexLock ml(bytes_mutex);
      int64 remaining = (int64)MAX_BYTES - (int64)bytes_used;
      if (remaining > FRAME_SIZE_UPPERBOUND) {
	bytes_used += FRAME_SIZE_UPPERBOUND;
	budget = FRAME_SIZE_UPPERBOUND;
      }
    }

    // Always try grabbing this, because we need to tell if
    // we should die.
    SDL_LockMutex(input_mutex);
    if (input_thread_should_die) {
      SDL_UnlockMutex(input_mutex);
      return 0;
    }

    if (budget > 0) {
      if (!input_queue.empty()) {
	InputQueueItem *iqi = input_queue.front();
	input_queue.pop_front();

	// We have our item; safe to unlock.
	SDL_UnlockMutex(input_mutex);

	uint64 bytes_actually_used = 0ULL;
	{
	  int sf = iqi->source_frame;
	  MutexLock ml(frames[iqi->source_frame].mutex);
	  // Don't really care if it fails rarely; this is just
	  // optimistic.
	  if (MaybeMakeFrame(iqi->index, sf, &frames[sf])) {
	    bytes_actually_used = frames[sf].graphy->BytesUsed();
	  }
	}
	CHECK(bytes_actually_used < budget);

	// We overestimated the amount of memory used. MaybeMakeFrame
	// does allocate on its own.
	// slop.
	{
	  MutexLock ml(bytes_mutex);
	  CHECK(bytes_used >= budget);
	  // Always return the whole budget; MaybeMakeFrame already
	  // accounted for what we actually used.
	  bytes_used -= budget;
	}
      } else {
	// Once queue is exhausted, don't need this thread any more.
	SDL_UnlockMutex(input_mutex);
	return 0;
      }
    } else {
      // Not going to do any work.
      SDL_UnlockMutex(input_mutex);
      // ... but don't spin-lock if starved.
      SDL_Delay(5);
    }
  }
}

struct Outputter {
  Outputter() : samples_until_frame(0), num_frames_output(0) {
    InitializeFrames();
    LoadScript();
    printf("Create input frame queue...\n");
    MakeInputFrameQueue();
    printf("   ... done.\n");

    font = Font::create(screen,
			"font.png",
			FONTCHARS,
			FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);
    CHECK(font);

    fontbig = Font::create(screen,
			   "fontbig.png",
			   FONTCHARS,
			   FONTBIGWIDTH,
			   FONTBIGHEIGHT,
			   FONTSTYLES,
			   2, 3);
    CHECK(fontbig);

    SDL_Surface *fm = sdlutil::LoadImage("fontmax.png");
    CHECK(fm);

    SDL_Surface *fm2x = sdlutil::grow2x(fm);
    CHECK(fm2x);

    fonthuge = Font::create_from_surface(screen,
					 fm,
					 FONTCHARS,
					 27 * 2, 48 * 2, FONTSTYLES, 3 * 2, 3);
    CHECK(fonthuge);

    fontmax = Font::create_from_surface(screen,
					fm2x,
					FONTCHARS,
					27 * 2 * 2, 48 * 2 * 2, 
					FONTSTYLES, 3 * 2 * 2, 3);
    CHECK(fontmax);

    frames_i_loaded = 0;

    static constexpr int OUTPUT_THREADS = 4;
    for (int i = 0; i < OUTPUT_THREADS; i++) {
      printf("Spawn output thread %d:\n", i);
      threads.push_back(SDL_CreateThread(ProcessOutputItemsThread,
					 (void *)NULL));
    }

    static constexpr int INPUT_THREADS = 4;
    for (int i = 0; i < INPUT_THREADS; i++) {
      printf("Spawn input thread %d:\n", i);
      threads.push_back(SDL_CreateThread(ProcessInputItemsThread,
					 (void *)NULL));
    }
  }

  // Wait for these at the end.
  vector<SDL_Thread *> threads;

  void WaitThreads() {
    {
      MutexLock ml(output_mutex);
      output_thread_should_die = true;
    }
    {
      MutexLock ml(input_mutex);
      input_thread_should_die = true;
    }

    printf("Waiting for threads to finish...\n");
    for (int i = 0; i < threads.size(); i++) {
      int ret_unused;
      SDL_WaitThread(threads[i], &ret_unused);
      printf ("Thread %d/%d done.\n", (i + 1), (int)threads.size());
    }
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

  vector<pair<float, float>> samples_out;

  // This is the number of samples we have until we need to output
  // another frame. We go a single sample at a time. Outputting a
  // frame gets us a budget of SAMPLES_PER_FRAME, duh.
  int samples_until_frame;
  // Number of frames we've output. 0-based.
  int num_frames_output;

  int frames_i_loaded;

  void OutputSample(int word_index, int s) {
    if (samples_until_frame == 0) {
      // We hope that the loading thread has pulled this bad boy in,
      // but if not, we'll do it here.
      int frame_num = FrameForSample(s);
      // PERF maybe count how often we block, or how much time we
      // spend waiting.

      // Take the lock. If it has data when we get it, great.
      // Otherwise, compute it and do everything with the lock held.
      SDL_LockMutex(frames[frame_num].mutex);
      if (MaybeMakeFrame(word_index, frame_num, &frames[frame_num])) {
	frames_i_loaded++;
	printf("Main thread load of #%d (%d total).\n", 
	       frame_num,
	       frames_i_loaded);
      }

      // Draw the frame.
      CHECK(frames[frame_num].graphy != NULL);
      frames[frame_num].graphy->BlitSwab(screen, 0, 0);
      SDL_Flip(screen);
     
      // Puts it in the output queue so that it can be processed by
      // the background thread. Eagerly frees the frame and releases
      // the lock.
      WriteFrameInBackgroundAndUnlock(&frames[frame_num], num_frames_output);
      num_frames_output++;

      samples_until_frame = SAMPLES_PER_FRAME;
    }
    pair<float, float> mag = GetAudioSample(s);
    samples_out.push_back(mag);
    samples_until_frame--;

    // XXX
    if (samples_out.size() > MAX_SAMPLES_DEBUG) {
      printf("Writing wave.\n");
      WaveSave::SaveStereo("starwars-sorted.wav",
			   samples_out,
			   AUDIO_SAMPLERATE);
      printf("Early exit.\n");
      return;
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
      
      // Read events once every word.
      SDL_Event event;
      while (SDL_PollEvent(&event)) {
	switch (event.type) {
	  case SDL_QUIT:
	    printf("Got quit.\n");
	    return;
	}
      }

      // Sample loop.
      for (int s = word.start_sample; s < word.end_sample; s++) {
	OutputSample(w, s);
      }
      double sec = time(NULL) - time_start;
      double sps = samples_out.size() / sec;
      double fps = num_frames_output / sec;

      double memfrac = 0.0;
      {
	MutexLock ml(bytes_mutex);
	double used = bytes_used;
	memfrac = used / MAX_BYTES;
      }

      int samples_left = num_sorted_samples - samples_out.size();
      double seconds_left = samples_left / sps;
      string timestring = GetMSPlain(seconds_left);
      printf("%d/%d (%.2f%%) %s  "
	     "%d ld, %d wrong, %d sps, %.2f fps, %.1f%% mem  %s\n", 
	     w, (int)sorted.size(),
	     (100.0 * w) / sorted.size(),
	     word.word.c_str(),
	     frames_i_loaded, frame_had_wrong_word,
	     (int)sps, fps, 
	     memfrac * 100.0,
	     timestring.c_str());
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
  SDL_Delay(1000);
  o.WaitThreads();

  SDL_Quit();
  return 0;
}
