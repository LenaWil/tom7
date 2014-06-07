/*
  This is an implementation of sample layer that contains
  infinite pseudorandom bleep-bloops. It is intended for testing.
*/

#ifndef __BLEEP_BLOOP_SAMPLE_LAYER_H
#define __BLEEP_BLOOP_SAMPLE_LAYER_H

#include "10goto20.h"
#include "sample-layer.h"

struct BleepBloopSampleLayer : public SampleLayer {

  static BleepBloopSampleLayer *Create();

  virtual bool FirstSample(int64 *t) { return false; }
  virtual bool AfterLastSample(int64 *t) { return false; }

  virtual Sample SampleAt(int64 t);
 private:
  // Use factory.
  BleepBloopSampleLayer();
};

#endif
