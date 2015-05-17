/*
  Test layer that applies a "reverb" effect. The goal is to exercise
  the design of the layer system (and rendering) so that it can handle
  effects that require not just the input time t, but some other layer's
  samples as well as some state. In particular, a sample at time t
  can be computed as a function:

    SampleAt(t,
      ... something that describes what samples from the underlying
          that it depends on ... (default = everything)
      ... some kind of "state" output of t-1 ...
   
    Start() ... returns the "state" for -infinity (infinite silence)

  Basically an unfold operation. 

*/

#ifndef __REVERB_LAYER_H
#define __REVERB_LAYER_H

#include "10goto20.h"
#include "sample.h"
#include "sample-layer.h"

struct ReverbLayer : public SampleLayer {
  // Using fixed parameters for now.
  explicit ReverbLayer(SampleLayer *layer) : layer(layer) {}

  // Since we render in blocks, we want to avoid a situation where
  // we have two threads rendering samples at e.g. t and t+1 where
  // they are both in the same block. If two samples have different
  // block IDs, then they may be rendered in parallel.
  int64 BlockId(int64 t);

  // Render 'size' samples starting at time 'start' into the
  // destination array. Expects exclusive access to that region of
  // memory while the call is outstanding, but must be thread safe
  // internally (i.e., support simultaneous calls). (TODO: Mutex
  // policies.)
  Render(int64 start, int64 size, Sample *dest);

 private:
  NOT_COPYABLE(ReverbLayer);
};

#endif
