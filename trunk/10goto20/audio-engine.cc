
#include "audio-engine.h"

#include "concurrency.h"
#include "10goto20.h"
#include "revision.h"
#include "interval-cover.h"

static constexpr int AUDIOBUFFER = 1024;

// These are static.
static Mutex mutex(Mutex::STATIC_UNINITIALIZED);
static int64 cursor = 0LL;
static int64 song_end = 0LL;
static bool playing = false;
static SampleLayer *song = nullptr;

// This is our cache of samples, which is in tandem
// with the song.
static vector<Sample> *samples = nullptr;
// Marks the current revision of each sample in the vector.
// Values outside [0, samples->size()] are not meaningful.
typedef IntervalCover<Revision> SampleIC;
static IntervalCover<Revision> sample_rev(Revisions::NEVER);
// We don't care about last-changed because we just use this
// for audio output.

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
  SampleIC::Span span = sample_rev.GetPoint(cursor);
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
  MutexLock ml(&mutex);
  SampleLayer *ret = song;
  song = new_layer;
  // Mark all samples as out of date.
  sample_rev.SetSpan(LLONG_MIN, LLONG_MAX, Revisions::NEVER);
  return ret;
}
