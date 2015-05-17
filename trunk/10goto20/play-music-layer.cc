#include "play-music-layer.h"

// TODO: PERF: These waveforms are pretty core, and no attempt
// has been made to optimize them.

PlayMusicLayer::PlayMusicLayer(MusicLayer *music) : music(music) {}

bool PlayMusicLayer::FirstSample(int64 *t) {
  return music->FirstSample(t);
}

bool PlayMusicLayer::AfterLastSample(int64 *t) {
  return music->AfterLastSample(t);
}

namespace {
struct SineML : public PlayMusicLayer {
  SineML(MusicLayer *music) : PlayMusicLayer(music) {}
  Sample SampleAt(int64 t) override {
    vector<Controllers> cs = music->NotesAt(t);
    Sample ret(0.0);
    double seconds = t / (double)SAMPLINGRATE;
    for (int i = 0; i < cs.size(); i++) {
      const Controllers &c = cs[i];
      double freq = c.GetRequired(FREQUENCY);
      // XXX some solution for putting amplitude in a
      // reasonable range. For sine this is particularly
      // challenging because different frequencies seem
      // to have very different perceived loudness.
      double amplitude = c.GetRequired(AMPLITUDE) * 0.10;
      double value = sin(TWOPI * freq * seconds) * amplitude;
      ret = ret + Sample(value);
    }

    return ret;
  }
};

struct SquareML : public PlayMusicLayer {
  SquareML(MusicLayer *music) : PlayMusicLayer(music) {}

  // Square wave requires some oversampling, or else we
  // get clicky.
  static constexpr int OVERSAMPLE = 4;
  Sample SampleAt(int64 t) override {
    vector<Controllers> cs = music->NotesAt(t);
    Sample ret(0.0);
    for (int i = 0; i < cs.size(); i++) {
      const Controllers &c = cs[i];
      double amplitude = c.GetRequired(AMPLITUDE) * 0.10;
      // Frequency is not affected by oversampling, just the
      // effective sampling rate.
      double freq = c.GetRequired(FREQUENCY);

      // Get 4 consecutive samples starting at t, but at 4x the
      // sampling rate. Then average them.
      Sample oversampled_sample(0.0);
      // TODO: Maybe it would be better to go from -OVERSAMPLE/2 to 
      // +OVERSAMPLE/2? This introduces a slight phase artifact.
      for (int os = 0; os < OVERSAMPLE; os++) {
	double seconds = (OVERSAMPLE * t + os) / 
	  (double)(OVERSAMPLE * SAMPLINGRATE);
	
	// If we're at time 0.1s, but playing a 10Hz wave, that's the
	// very end of the waveform. Multiply and truncate to get a
	// position within the waveform of in [0, 1).
	double untrunc = seconds * freq;
	double pos = untrunc - trunc(untrunc);

	// TODO: Easy to implement duty cycle here, by adjusting the
	// value 0.5.

	double value = (pos < 0.5) ? 1.0 : -1.0;

	oversampled_sample += Sample(value);
      }

      // Now take the average of these.
      oversampled_sample /= (double)OVERSAMPLE;

      // And mix with the rest of the notes. Amplitude is same for
      // all of them so just do that last.
      ret += oversampled_sample * amplitude;
    }
    return ret;
  }
};

struct SawML : public PlayMusicLayer {
  SawML(MusicLayer *music) : PlayMusicLayer(music) {}

  static constexpr int OVERSAMPLE = 4;
  Sample SampleAt(int64 t) override {
    vector<Controllers> cs = music->NotesAt(t);
    Sample ret(0.0);
    for (int i = 0; i < cs.size(); i++) {
      const Controllers &c = cs[i];
      double amplitude = c.GetRequired(AMPLITUDE) * 0.10;
      double freq = c.GetRequired(FREQUENCY);

      Sample oversampled_sample(0.0);
      for (int os = 0; os < OVERSAMPLE; os++) {
	double seconds = (OVERSAMPLE * t + os) / 
	  (double)(OVERSAMPLE * SAMPLINGRATE);
	double untrunc = seconds * freq;
	double pos = untrunc - trunc(untrunc);
	double value = pos * 2.0 - 1.0;
	oversampled_sample += Sample(value);
      }

      oversampled_sample /= (double)OVERSAMPLE;
      ret += oversampled_sample * amplitude;
    }
    return ret;
  }
};


// TODO SAW, TRIANGLE, etc.
}  // namespace

PlayMusicLayer *PlayMusicLayer::Create(MusicLayer *music,
				       Instrument inst) {
  switch (inst) {
  case SINE:
    return new SineML(music);
  case SAWTOOTH:
    return new SawML(music);
  case TRIANGLE:
    CHECK(!"unimplemented triangle");
  case SQUARE:
    return new SquareML(music);
  default:
    fprintf(stderr, "Unknown instrument %d\n", inst);
    return nullptr;
  }
}
