
#include "reverb-layer.h"

#include <vector>

#include "10goto20.h"

namespace {
struct RL : public ReverbLayer {

  // TODO: This is a copy of mixlayer, and is garbage
  RL(SampleLayer *layer) : layer(layer) {
    lb = ub = 0;
    bool hasl = false, hasu = false;
    right_infinite = left_infinite = false;
    for (SampleLayer *layer : layers) {
      int64 t;
      if (layer->FirstSample(&t)) {
	if (!hasl || t < lb) {
	  hasl = true;
	  lb = t;
	}
      } else {
	left_infinite = true;
      }
      
      if (layer->AfterLastSample(&t)) {
	if (!hasu || t > ub) {
	  hasu = true;
	  ub = t;
	}
      } else {
	right_infinite = true;
      }
    }
  }
  
  bool FirstSample(int64 *t) {
    if (left_infinite) return false;
    *t = lb;
    return true;
  }

  bool AfterLastSample(int64 *t) {
    if (right_infinite) return false;
    *t = ub;
    return true;
  }

  Sample SampleAt(int64 t) {
    // XXX this asks for samples outside the finite range
    // for finite layers. Should maybe update the docs, or fix that?
    Sample s(0.0);
    for (SampleLayer *layer : layers) {
      s += layer->SampleAt(t);
    }
    return s;
  }

 private:
  bool left_infinite, right_infinite;
  int64 lb, ub;
  SampleLayer *layer;
};
}

ReverbLayer *ReverbLayer::Create(SampleLayer *layer) {
  return new RL(layer);
}
