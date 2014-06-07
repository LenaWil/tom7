/*
  A sample layer is a layer that generates audio samples. This
  is an abstract interface.

  This is a common and basic layer that results from rendering
  of audio, like a synthesizer or sampler.

  A sample layer is a partial function from time (sample number) to
  amplitude. The layers are positioned in time, and do not necessarily
  have a beginning or end. For example, it may be an infinite 60 Hz
  sinewave with a specific phaseor a drum sample that plays for 100ms,
  starting at sample #139741. Although sample layers have their own
  notion of timing, it makes sense to construct a new sample layer
  by offsetting or cropping an existing one.
*/

#ifndef __SAMPLE_LAYER_H
#define __SAMPLE_LAYER_H

#include "10goto20.h"

struct SampleLayer {

  // If this is a left-finite layer, return true and set the argument
  // to the first sample of the clip. If left-infinite, return false.
  virtual bool FirstSample(int64 *t) = 0;
  // If this is a right-finite layer, return true and set the argument
  // to one past the last sample of the clip.
  virtual bool AfterLastSample(int64 *t) = 0;

  // Compute the sample at the given time. Must only be called
  // for finite clips when this is within the bounds of the clip.
  // The layer is responsible for doing its own caching and
  // maintenance of dependents that may have become dirty.
  virtual Sample SampleAt(int64 t) = 0;

  // TODO: Something to describe which regions have changed since
  // some iteration (we need some kind of global clock that
  // advances with any change, so that we can ask: Are samples
  // I read from you at iteration i still valid?)
  // For example, it could cover all of time with a series of
  // intervals, which describe the last-changed time?

};

#endif
