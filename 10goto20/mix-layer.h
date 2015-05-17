/*
  Simple layer that mixes the underlying layers.
*/

#ifndef __MIX_LAYER_H
#define __MIX_LAYER_H

#include <vector>

#include "10goto20.h"
#include "sample-layer.h"

struct MixLayer : public SampleLayer {
  static MixLayer *Create(const std::vector<SampleLayer *> &layers);

  bool FirstSample(int64 *t) override = 0;
  bool AfterLastSample(int64 *t) override = 0;
  Sample SampleAt(int64 t) override = 0;
};

#endif
