
#include "audio-engine.h"
#include "concurrency.h"
#include "10goto20.h"

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


// Callback for audio processing.
static void AudioCallback(void *userdata,
			  uint8 *stream_bytes, int num_bytes) {
  static_assert(sizeof (Sint16) == 2, "Expected Sint16 to be 16 bits.");
  Sint16 *stream = (Sint16*) stream_bytes;
  int nsamples = num_bytes >> 1;

  MutexLock ml(&mutex);
  // A "sample" here means a single sample on a single channel. There are
  // two channels so go by two, even though capital-s Sample is a pair
  // of stereo samples.
  for (int i = 0; i < nsamples; i += 2) {
    if (!playing || cursor == song_end) {
      // Output silence on both channels. We need to finish out
      // the buffer with silence even if we are pausing audio, since
      // the buffer may contain old samples otherwise.
      stream[i] = 0;
      stream[i + 1] = 0;
    } else {
      if (true /* XXX check that sample at cursor is ready */) {
	Sample s = (*samples)[cursor];
	stream[i] = DoubleTo16(s.left);
	stream[i + 1] = DoubleTo16(s.right);
	cursor++;
      } else {
	playing = false;
	// TODO: Can we pause audio from the audio thread?
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

  // TODO: Can usually preserve samples, especially when
  // getting smaller, but simplest policy is to just
  // start over.
  delete samples;
  samples = new vector<Sample>(song_end, Sample(0.0));
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
