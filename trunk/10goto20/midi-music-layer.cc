
#include "midi-music-layer.h"

#include "10goto20.h"

#include "jdksmidi/world.h"
#include "jdksmidi/track.h"
#include "jdksmidi/multitrack.h"
#include "jdksmidi/filereadmultitrack.h"
#include "jdksmidi/fileread.h"
#include "jdksmidi/fileshow.h"

using namespace jdksmidi;


void DumpMIDITimedBigMessage (const MIDITimedBigMessage *msg) {
  if (msg) {
    char msgbuf[1024];
    fprintf (stdout, "%8ld : %s\n", msg->GetTime(), msg->MsgToText (msgbuf));
    
    if (msg->IsSystemExclusive()) {
      fprintf (stdout, "\tSYSEX length: %d\n", msg->GetSysEx()->GetLength());
    }
  }
}

void DumpMIDITrack (MIDITrack *t) {
  MIDITimedBigMessage *msg;
  
  for (int i = 0; i < t->GetNumEvents(); ++i) {
    msg = t->GetEventAddress (i);
    DumpMIDITimedBigMessage (msg);
  }
}

void DumpAllTracks (MIDIMultiTrack *mlt) {
  for (int i = 0; i < mlt->GetNumTracks(); ++i) {
    if (mlt->GetTrack (i)->GetNumEvents() > 0) {
      fprintf (stdout, "DUMP OF TRACK #%2d:\n", i);
      DumpMIDITrack (mlt->GetTrack (i));
      fprintf (stdout, "\n");
    }
  }
}
  
void DumpMIDIMultiTrack (MIDIMultiTrack *mlt) {
  fprintf(stderr, "Dump midi...\n");
  MIDIMultiTrackIterator i (mlt);
  const MIDITimedBigMessage *msg;
  i.GoToTime (0);

  do {
    int trk_num;

    if (i.GetCurEvent (&trk_num, &msg)) {
      fprintf (stdout, "#%2d - ", trk_num);
      DumpMIDITimedBigMessage (msg);
    }
  }
  while (i.GoToNextEvent());
}


// HERE

  {
    jdksmidi::MIDIFileReadStreamFile rs("sensations.mid");
    jdksmidi::MIDIMultiTrack tracks;
    jdksmidi::MIDIFileReadMultiTrack track_loader(&tracks);
    jdksmidi::MIDIFileRead reader(&rs, &track_loader);
    reader.Parse();
    DumpMIDIMultiTrack(&tracks);
  }
