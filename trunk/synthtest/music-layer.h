/*
  A music layer is a layer that generates audio musics. This
  is an abstract interface.

  Music is a function from sample time t to a multiset of notes. A
  note is itself a set of controllers; each controller at least
  includes frequency and amplitude, but the set of possible
  controllers is open. For example,

*/

#ifndef __MUSIC_LAYER_H
#define __MUSIC_LAYER_H

#include "10goto20.h"

struct MusicLayer {

  // If this is a left-finite layer, return true and set the argument
  // to the first music of the clip. If left-infinite, return false.
  virtual bool FirstMusic(int64 *t);
  // If this is a right-finite layer, return true and set the argument
  // to one past the last music of the clip.
  virtual bool AfterLastMusic(int64 *t);

  // Compute the music at the given time. Must only be called
  // for finite clips when this is within the bounds of the clip.
  // The layer is responsible for doing its own caching and
  // maintenance of dependents that may have become dirty.
  virtual double MusicAt(int64 t) = 0;

  // TODO: Something to describe which regions have changed since
  // some iteration (we need some kind of global clock that
  // advances with any change, so that we can ask: Are musics
  // I read from you at iteration i still valid?)
  // For example, it could cover all of time with a series of
  // intervals, which describe the last-changed time?

};

#endif
