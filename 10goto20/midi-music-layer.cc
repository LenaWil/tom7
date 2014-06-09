
#include "midi-music-layer.h"

#include "10goto20.h"

#include "jdksmidi/world.h"
#include "jdksmidi/track.h"
#include "jdksmidi/multitrack.h"
#include "jdksmidi/filereadmultitrack.h"
#include "jdksmidi/fileread.h"
#include "jdksmidi/fileshow.h"

#include "interval-tree.h"

using namespace jdksmidi;

static void DumpMIDITimedBigMessage(const MIDITimedBigMessage *msg) {
  if (msg) {
    char msgbuf[1024];
    fprintf(stdout, "%8ld : %s\n", msg->GetTime(), msg->MsgToText(msgbuf));
    
    if (msg->IsSystemExclusive()) {
      fprintf(stdout, "\tSYSEX length: %d\n", msg->GetSysEx()->GetLength());
    }
  }
}

#if 0
static void DumpMIDITrack(MIDITrack *t) {
  MIDITimedBigMessage *msg;
  
  for (int i = 0; i < t->GetNumEvents(); ++i) {
    msg = t->GetEventAddress(i);
    DumpMIDITimedBigMessage(msg);
  }
}

static void DumpAllTracks(MIDIMultiTrack *mlt) {
  for (int i = 0; i < mlt->GetNumTracks(); ++i) {
    if (mlt->GetTrack(i)->GetNumEvents() > 0) {
      fprintf(stdout, "DUMP OF TRACK #%2d:\n", i);
      DumpMIDITrack(mlt->GetTrack(i));
      fprintf(stdout, "\n");
    }
  }
}
#endif
  
static void DumpMIDIMultiTrack(MIDIMultiTrack *mlt) {
  fprintf(stderr, "Dump midi...\n");
  MIDIMultiTrackIterator i(mlt);
  const MIDITimedBigMessage *msg;
  i.GoToTime(0);

  do {
    int trk_num;

    if(i.GetCurEvent(&trk_num, &msg)) {
      fprintf(stdout, "#%2d - ", trk_num);
      DumpMIDITimedBigMessage(msg);
    }
  }
  while (i.GoToNextEvent());
}

// Only these are decoded for now.
enum MidiEventType {
  MIDI_NOTEON = 1,
  MIDI_NOTEOFF = 2,
};

struct MidiNote {
  MidiEventType type;
  // XXX...
};

// static
vector<MidiMusicLayer *> MidiMusicLayer::Create(const string &filename) {
  jdksmidi::MIDIFileReadStreamFile rs(filename.c_str());
  jdksmidi::MIDIMultiTrack tracks;
  jdksmidi::MIDIFileReadMultiTrack track_loader(&tracks);
  jdksmidi::MIDIFileRead reader(&rs, &track_loader);
  reader.Parse();
  // DumpMIDIMultiTrack(&tracks);

  vector<MidiMusicLayer *> layers;
  for (int i = 0; i < tracks.GetNumTracks(); i++) {
    MIDITrack *track = tracks.GetTrack(i);
    if (!track->IsTrackEmpty()) {
      track->SortEventsOrder();
      int removed = track->RemoveIdenticalEvents();
      printf("There were %d identical events, removed\n",
	     removed);
      for (int e = 0; e < track->GetNumEvents(); e++) {
	const MIDITimedBigMessage *msg = track->GetEvent(e);
	
      }
    }
  }
  

  CHECK(!"unimplemented");
  return layers;
}

