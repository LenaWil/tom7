
#include "mix-layer.h"

#include <vector>

#include "10goto20.h"

using namespace std;
namespace {
struct MLReal : public MixLayer {
  MLReal(const vector<SampleLayer *> &layers) : layers(layers) {
    lb = ub = 0;
    bool hasl = false, hasu = false;
    right_infinite = left_infinite = false;
    for (int i = 0; i < layers.size(); i++) {
      SampleLayer *layer = layers[i];
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
	if (!hasl || t > ub) {
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
    for (int i = 0; i < layers.size(); i++) {
      s += layers[i]->SampleAt(t);
    }
    return s;
  }

 private:
  bool left_infinite, right_infinite;
  int64 lb, ub;
  const vector<SampleLayer *> layers;
};
}

MixLayer *MixLayer::Create(const vector<SampleLayer *> &layers) {
  return new MLReal(layers);
}
