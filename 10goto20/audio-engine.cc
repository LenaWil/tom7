
#include "audio-engine.h"

#include "concurrency.h"
#include "10goto20.h"
#include "revision.h"
#include "interval-cover.h"
#include "base/stringprintf.h"

static constexpr int RENDER_THREADS = 6;
// PERF: Tune this number!
static constexpr int MAX_RENDER_CHUNK = 32768;
static constexpr int AUDIOBUFFER = 1024;

enum SampleLock {
  UNLOCKED = -1,
  GLOBAL_LOCK = -2,
};

#define lprintf(...) do { ; } while(0)

// These are static.
// Coarse locking. Many threads contend for this mutex, so it should
// not be held for long operations. In particular, we should just do
// data structure manipulations, memory copies, and that kind of
// stuff, no actual sample computation (which takes unbounded time).
static Mutex mutex(Mutex::STATIC_UNINITIALIZED);
static int64 cursor = 0LL;
static int64 song_end = 0LL;
static bool playing = false;
static SampleLayer *song = nullptr;
struct RenderThread;
static vector<RenderThread *> render_threads;

// ??!??!
static vector<bool> i_have_mutex;
// While holding the global mutex.
void WhoHasMutex(int caller) {
  CHECK(i_have_mutex.size() == RENDER_THREADS);
  string s;
  for (int i = 0; i < i_have_mutex.size(); i++) {
    s += StringPrintf("%d. %s%s\n",
		      i, 
		      (i_have_mutex[i] ? "YES" : "NO"),
		      (i == caller) ? " (me)" : "");
		      
  }
  lprintf(" === Who has mutex? By %d === \n"
	  "%s"
	  " ===================== %d === \n",
	  caller, s.c_str(), caller);
}

// This is our cache of samples, which is in tandem
// with the song.
static vector<Sample> *samples = nullptr;
// Marks the current revision of each sample in the vector.
// Values outside [0, samples->size()] are not meaningful.
typedef IntervalCover<Revision> SampleRevIC;
typedef IntervalCover<int> SampleLockIC;
// Used by render threads to lock regions. The region is unlocked
// if it is marked as -1. Otherwise, it is an index of a render
// thread.
static SampleRevIC sample_rev(Revisions::NEVER);
static SampleLockIC sample_lock(UNLOCKED);

// We don't care about last-changed because we just use this
// for audio output. (Conceivably we could use it to save
// the wave file to disk efficiently?)


// A thread that renders from 'layer' into 'samples', as needed. The
// intention is for it to be safe to run many of these. The object
// wraps all the thread-local data, where RunExt can be run as a
// thread with the thread object itself being the argument. No other
// thread should touch the thread data 
struct RenderThread {
  explicit RenderThread(int id) : id(id) {
    // Correctness of locks require ids to be non-negative.
    CHECK(id >= 0);
    lprintf("[%d] Created render thread.\n", id);
  }

  // Mutex protecting the thread's data, like should_die.
  Mutex local_mutex;

  // Main thread can kill the thread by taking the mutex and setting
  // this to true.
  bool should_die = false;

  const int id;

  static int RunExt(void *that) {
    // Don't start until global mutex is released.
    mutex.Lock();
    mutex.Unlock();

    ((RenderThread *)that)->Loop();
    return 0;
  }

 private:
  // Takes the global lock. Finds an interval that is unlocked
  // and behind the current revision. Reserves it by locking it
  // in the SampleLockIC. Returns false if there are no such
  // intervals.
  bool ReserveWork(Revision target_revision,
		   int64 *start, int64 *end) {
    MutexLock ml(&mutex);
    CHECK(!i_have_mutex[id]);
    i_have_mutex[id] = true;
    WhoHasMutex(id);
    
    lprintf("\nThread %d get work for rev %lld\n", id, target_revision);
    // sample_lock.DebugPrint();
    // fflush(stdout);

    // TODO PERF: Save some kind of hint about where to start
    // the search. All the threads end up searching the prefix
    // over and over.
    for (int64 pos = 0LL; !sample_lock.IsAfterLast(pos); 
	 pos = sample_lock.Next(pos)) {
      SampleLockIC::Span span = sample_lock.GetPoint(pos);
      lprintf("[%d] Consider %lld to %lld which has %d.\n",
	      id, span.start, span.end, span.data);
      CHECK(span.start != span.end);

      // PERF if we see GLOBAL_LOCK, should we also exit early?
      if (span.data == UNLOCKED) {
	// We found a region that's unlocked. Is there any work
	// to do in it?

	// The test that pp < span.end also implies that
	// !sample_rev.IsAfterLast(pp) is true.
	for (int64 pp = span.start; pp < span.end;
	     pp = sample_rev.Next(pp)) {
	  SampleRevIC::Span ss = sample_rev.GetPoint(pp);

	  lprintf("[%d] Check rev %lld to %lld which has %lld.\n",
		  id, ss.start, ss.end, ss.data);
	  CHECK(ss.start != ss.end);

	  if (ss.data < target_revision) {
	    // Found something! Note that ss could easily
	    // expand outside the locked region. So first
	    // compute the intersection of the two spans:

	    // span.start must be within both intervals!
	    lprintf("[%d] Intersect.\n", id);
	    int64 ival_start, ival_end;
	    CHECK(SampleLockIC::IntersectWith<SampleRevIC::Data>(span, ss, 
								 &ival_start,
								 &ival_end));
	    DCHECK(ival_start < ival_end);
	    lprintf("[%d] Got %lld to %lld back.\n", id, ival_start, ival_end);
	    

	    // Don't render before 0, or after the song's end.
	    ival_start = max(0LL, ival_start);
	    ival_end = min(song_end, ival_end);

	    // We can claim anything in [ival_start, ival_end),
	    // but let's not take chunks that are too big.
	    ival_end = min(ival_end, ival_start + MAX_RENDER_CHUNK);

	    // Intervals shouldn't be empty, but since we did some
	    // min/max stuff, they can be now. (For example, if the
	    // song is 0 samples long, this will always happen.)
	    if (ival_start == ival_end) {
	      lprintf("[%d] Degenerate span @%lld\n", id, ival_start);
	      continue;
	    }

	    lprintf("[%d] After trim: %lld to %lld\n",
		    id, ival_start, ival_end);

	    // sample_lock.DebugPrint();
	    sample_lock.CheckInvariants();
	    lprintf("[%d] Invariants look OK?\n", id);

	    // Reserve it while we have the mutex.
	    sample_lock.SetSpan(ival_start, ival_end, id);
	    lprintf("[%d] Successfully set span...\n", id);

	    *start = ival_start;
	    *end = ival_end;
	    
	    lprintf("[%d] Reserved span %lld to %lld.\n", id,
		    ival_start, ival_end);
	    i_have_mutex[id] = false;
	    return true;
	  } else {
	    lprintf("[%d] .. it's up to date.\n", id);
	  }
	  // TODO PERF: Else check if the revision is in
	  // the future. This tells us that we're behind
	  // and should probably just exit early.
	}
      }
    }

    // No unlocked region to operate on.
    lprintf("[%d] Exhausted all spans with no work found.\n", id);
    i_have_mutex[id] = false;
    return false;
  }

  // This stuff should only be accessed by the thread itself.
  void Loop() {
    // Main loop.

    for (;;) {
      if (local_mutex.AtomicRead(&should_die)) return;

      // Try to find some work.
      Revision r = Revisions::GetRevision();
     
      // We can only do work on unlocked regions, so start
      // with that.
      int64 start, end;
      if (ReserveWork(r, &start, &end)) {
	// Now compute the samples into a separate buffer.
	// We need to make sure the song doesn't change from
	// under us! How?
	CHECK(end > start);
	int64 size = end - start;
	// PERF this could just be thread-local.
	vector<Sample> buffer(end - start, Sample(0.0));
	if (song != nullptr) {
	  for (int64 i = 0; i < size; i++) {
	    buffer[i] = song->SampleAt(start + i);
	  }
	}

	// Take the mutex to write the samples back, but note that the
	// vector might have been resized while we were gone, so only
	// write within the valid region.
	{
	  MutexLock ml(&mutex);
	  if (end <= samples->size()) {
	    for (int64 i = 0; i < size; i++) {
	      (*samples)[start + i] = buffer[i];
	    }
	    sample_rev.SetSpan(start, end, r);
	  } else {
	    lprintf("[%d] Buffer was resized unfavorably; "
		    "discarding my chunk.", id);
	  }

	  sample_lock.SetSpan(start, end, UNLOCKED);
	}
	// Slow motion...
	// SDL_Delay(1000);


      } else {
	// If starved, don't spin-lock.
	SDL_Delay(5);
      }
    }
  }
};

// Callback for audio processing.
static void AudioCallback(void *userdata,
			  uint8 *stream_bytes, int num_bytes) {
  static_assert(sizeof (Sint16) == 2, "Expected Sint16 to be 16 bits.");
  Sint16 *stream = (Sint16*) stream_bytes;
  // A "sample" here means a single sample on a single channel. There are
  // two channels so go by two, even though capital-s Sample is a pair
  // of stereo samples.
  int nsamples = num_bytes >> 1;

  const Revision expected_revision = Revisions::GetRevision();

  MutexLock ml(&mutex);

  // Avoid looking up the span (log n time) for each timestep;
  // it doesn't change that often.
  SampleRevIC::Span span = sample_rev.GetPoint(cursor);
  // Loop invariant: cursor is >= span.start.
  for (int i = 0; i < nsamples; i += 2) {
    // Would be a bug. We hold the mutex so nobody should be moving
    // the cursor but us.
    DCHECK(cursor >= span.start);
    // But we might have exited the span and need the next one.
    if (cursor >= span.end) {
      span = sample_rev.GetPoint(span.end);
      DCHECK(cursor >= span.start);
    }

    DCHECK(cursor < span.end);

    if (!playing || cursor == song_end) {
      // Output silence on both channels. We need to finish out
      // the buffer with silence even if we are pausing audio, since
      // the buffer may contain old samples otherwise.
      stream[i] = 0.0;
      stream[i + 1] = 0.0;
    } else {
      // Is the sample up-to-date?
      if (span.data == expected_revision) {
	Sample s = (*samples)[cursor];
	stream[i] = DoubleTo16(s.left);
	stream[i + 1] = DoubleTo16(s.right);
	cursor++;
      } else {
	stream[i] = 0.0;
	stream[i + 1] = 0.0;
	playing = false;
      }
    }
  }
}

int64 AudioEngine::GetCursor() {
  MutexLock ml(&mutex);
  return cursor;
}

void AudioEngine::SetCursor(int64 c) {
  MutexLock ml(&mutex);
  cursor = c;
  if (cursor < 0LL) cursor = 0LL;
  else if (cursor > song_end) cursor = song_end;
}

void AudioEngine::Init() {
  CHECK(!mutex.Initialized());
  mutex.Init();
  CHECK(mutex.Initialized());
  song_end = 60 * SAMPLINGRATE;
  samples = new vector<Sample>(song_end, Sample(0.0));
  cursor = 0LL;
  // TODO: Maybe should init to a silence layer so that
  // we don't have to do null checks?
  song = nullptr;

  SDL_AudioSpec spec, obtained;
  // Maybe this doesn't have to match the rendered sampling
  // rate, if we're willing to do some down/upsampling in
  // the output routine (which would be reasonable?).
  spec.freq = SAMPLINGRATE;
  spec.samples = AUDIOBUFFER;
  spec.channels = 2;
  spec.callback = &AudioCallback;
  spec.userdata = 0;
  // It'd be nice if we could output in 24 bit (or better)
  // since everything is done with doubles. Requires SDL 2.0,
  // though.
  spec.format = AUDIO_S16SYS;
  SDL_OpenAudio(&spec, &obtained);

  fprintf(stderr, "Audio started: %d Hz %d buffer\n",
	  obtained.freq, obtained.samples);

  MutexLock ml(&mutex);
  // Start rendering threads.
  for (int i = 0; i < RENDER_THREADS; i++)
    render_threads.push_back(new RenderThread(i));
  for (RenderThread *rt : render_threads) {
    SDL_Thread *th = SDL_CreateThread(RenderThread::RunExt,
				      (void *)rt);
    // XXX don't discard the thread pointer; keep it in some
    // structure (or write it into the thread object?)
    (void)th;
    i_have_mutex.push_back(false);
  }
  
  CHECK(render_threads.size() == RENDER_THREADS);
  CHECK(i_have_mutex.size() == render_threads.size());
}

void AudioEngine::SetEnd(int64 new_song_end) {
  MutexLock ml(&mutex);
  song_end = max(new_song_end, 0LL);

  // TODO PERF: Can usually preserve samples, especially when getting
  // smaller, but simplest policy is to just start over.
  delete samples;
  samples = new vector<Sample>(song_end, Sample(0.0));
  // Mark everything as uncomputed.
  sample_rev.SetSpan(LLONG_MIN, LLONG_MAX, Revisions::NEVER);

  cursor = min(cursor, new_song_end);
}

bool AudioEngine::Playing() {
  MutexLock ml(&mutex);
  return playing;
}

void AudioEngine::Play(bool p) {
  MutexLock ml(&mutex);
  playing = p;
  SDL_PauseAudio(!playing);
}

// static
void AudioEngine::BlockingRender() {
  // XXX need to make this safe with audio rendering threads
  // running in parallel -- it needs to observe sample_lock!
  UNIMPLEMENTED("not compatible with render threads yet");

  MutexLock ml(&mutex);
  fprintf(stderr, "BlockingRender:\n");

  if (song == nullptr) {
    fprintf(stderr, "No song in BlockingRender..?\n");
    return;
  }

  // TODO: But what's to say that the samples we generate
  // aren't actually from AFTER this? Maybe we should be
  // checking that as we read them. Or maybe the revision
  // we write should be computed only from the samples we
  // read / compute.
  const Revision current_revision = Revisions::GetRevision();

  for (int64 i = 0LL; i < song_end; i++) {
    (*samples)[i] = song->SampleAt(i);
    sample_rev.SetSpan(i, i + 1LL, current_revision);
  }

  fprintf(stderr, "Rendered %lld samples.\n", song_end);
}

SampleLayer *AudioEngine::SwapLayer(SampleLayer *new_layer) {
  // Maybe can just pause the threads or something?
  auto LockEverything = []() -> bool{
    MutexLock ml(&mutex);
    bool again = false;
    for (int64 pos = sample_lock.First(); 
	 !sample_lock.IsAfterLast(pos);
	 pos = sample_lock.Next(pos)) {
      SampleLockIC::Span s = sample_lock.GetPoint(pos);
      if (s.data >= 0) {
	again = true;
	lprintf("Still blocked on %lld--%lld (thread %d).\n", 
		s.start, s.end, s.data);
      } else {
	// TODO use constants for this...
	sample_lock.SetSpan(s.start, s.end, -2);
      }
    }
    return again;
  };

  // Get exclusive access to the song, by making sure we lock
  // every sample.
  while (LockEverything()) {
    lprintf(" .. still locking everything.\n");
  }
  lprintf("Done locking everything!\n");

  // Now that the render threads are locked out, we can do some
  // violence.
  MutexLock ml(&mutex);
  SampleLayer *ret = song;
  song = new_layer;
  // Mark all samples as out of date.
  sample_rev.SetSpan(LLONG_MIN, LLONG_MAX, Revisions::NEVER);

  // Unlock samples too.
  sample_lock.SetSpan(LLONG_MIN, LLONG_MAX, UNLOCKED);
  lprintf("Done with SwapLayer!\n");
  return ret;
}

// static 
pair<IntervalCover<int>, IntervalCover<Revision>> AudioEngine::GetSpans() {
  MutexLock ml(&mutex);
  return make_pair(sample_lock, sample_rev);
}

int64 AudioEngine::GetEnd() {
  MutexLock ml(&mutex);
  return song_end;
}
