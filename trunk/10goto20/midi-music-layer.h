/*
  This is a music layer implemented with MIDI.

  I haven't determined the proper editable representation for music
  yet, so this is just a static stand-in for testing. Soon, this
  should be replaced with a read-write music layer implementation
  which can be imported to from midi files.
*/

#ifndef __MIDI_MUSIC_LAYER_H
#define __MIDI_MUSIC_LAYER_H

#include <string>
#include <vector>

#include "10goto20.h"
#include "music-layer.h"
#include "controllers.h"

struct MidiMusicLayer : public MusicLayer {

  // Returns a vector of all the tracks that have notes in the
  // original. The idea is that each track is one instrument/channel,
  // which is not required by MIDI but is typical for multitrack
  // files.
  static vector<MidiMusicLayer *> Create(const string &filename);


  // TODO: bool Name() const;
  // Get the MIDI instrument for the track. Takes the first one.
  virtual int MidiInstrument() const = 0;

  bool FirstSample(int64 *t) override = 0;
  bool AfterLastSample(int64 *t) override = 0;

  virtual vector<Controllers> NotesAt(int64 t) = 0;

 protected:
  // Use factory.
  MidiMusicLayer();
};

#endif
