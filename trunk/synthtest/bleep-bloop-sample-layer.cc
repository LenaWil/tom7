#include "10goto20.h"
#include "bleep-bloop-sample-layer.h"

#define NOTES_PER_SECOND 10
static const int SAMPLES_PER_NOTE = SAMPLINGRATE / NOTES_PER_SECOND;
#define AMPLITUDE 0.15

static int64 Randy(int64 i) {
  i = i * 31337LL;
  i = ((uint64)i << 60 | (uint64)i >> 4);
  i ^= 0xDEADBEEFCAFEBABELL;
  i += 0x314159265389LL;
  return i;
}
  
// In Hz
static double RandomFreq(int64 i) {
  double d = (i % 10000000) / 10000000.0;
  d = d * d * d;
  return double(40 + d * 10000.0);
}

static double Sinewave(double freq, int64 samplet) {
  // XXX ?
  return AMPLITUDE * sin(TWOPI * freq * (samplet / (double)SAMPLINGRATE));
}

Sample BleepBloopSampleLayer::SampleAt(int64 t) {
  int64 notenum = t / SAMPLES_PER_NOTE;
  int64 r1 = Randy(notenum);
  int64 r2 = Randy(r1);
  
  double lfreq = RandomFreq(r1), rfreq = RandomFreq(r2);
  return Sample(Sinewave(lfreq, t), Sinewave(rfreq, t));
  // return Sample(Sinewave(261.63, t), Sinewave(392.0, t));
}

BleepBloopSampleLayer::BleepBloopSampleLayer() {}

BleepBloopSampleLayer *BleepBloopSampleLayer::Create() {
  return new BleepBloopSampleLayer();
}
