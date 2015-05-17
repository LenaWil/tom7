/*
  Layer that fixes up invalid samples (those outside [-1, 1], or NaN).
  This is not a good solution -- instead we should do some kind of
  global normalization that feeds back into the volumes of lower
  layers. It also makes sense to have an adaptive compressor. But
  until we have something good there (and to make sure that we don't
  just clip by modulus!), this harsh limiter will do the trick...
*/

#ifndef __SORRY_LAYER_H
#define __SORRY_LAYER_H

#include "10goto20.h"
#include "sample.h"
#include "sample-layer.h"

struct SorryLayer : public SampleLayer {
  explicit SorryLayer(SampleLayer *layer) : layer(layer) {}
  bool FirstSample(int64 *t) override { return layer->FirstSample(t); }
  bool AfterLastSample(int64 *t) override { return layer->AfterLastSample(t); }
  Sample SampleAt(int64 t) override {
    // TODO: much better clamping, please! Should probably ease
    // into and out of the limited regions.
    Sample s = layer->SampleAt(t);

    if (s.left != s.left) s.left = 0.0;
    else if (s.left > 1.0) s.left = 1.0;
    else if (s.left < -1.0) s.left = -1.0;

    if (s.right != s.right) s.right = 0.0;
    if (s.right > 1.0) s.right = 1.0;
    else if (s.right < -1.0) s.right = -1.0;

    return s;
  }

  SampleLayer *layer;
};

#endif
