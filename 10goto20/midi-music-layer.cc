
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

MidiMusicLayer::MidiMusicLayer() {}

static void DumpMIDITimedBigMessage(const MIDITimedBigMessage *msg) {
  if (msg) {
    char msgbuf[1024];
    fprintf(stdout, "%8ld : %s\n", msg->GetTime(), msg->MsgToText(msgbuf));
    
    if (msg->IsSystemExclusive()) {
      fprintf(stdout, "\tSYSEX length: %d\n", msg->GetSysEx()->GetLength());
    }
  }
}

struct Payload {
  // TODO: Not too hard to support pan and some other controllers.
  int note_index;
  // Velocity is always >0.
  int velocity;
};

struct MidiNote {
  int64 start, end;
  Payload payload;
};

static double MidiFrequency(int idx) {
  return 8.0 * pow(2.0, idx / 12.0);
}

struct RealMML : public MidiMusicLayer {
  typedef IntervalTree<int64, Payload> IT;

  RealMML(const vector<MidiNote> &notes, int midi_instrument) : 
    instrument(midi_instrument) {
    for (int i = 0; i < notes.size(); i++) {
      // PERF These are mostly time-sorted, and sorted insert is
      // worst case for this binary tree. Either have it be self-balancing
      // or insert in random order, or something.
      (void)tree.Insert(notes[i].start, notes[i].end, notes[i].payload);
    }
  }

  int MidiInstrument() const override { return instrument; }
  bool FirstSample(int64 *t) override {
    *t = tree.LowerBound();
    return true;
  }
  bool AfterLastSample(int64 *t) override {
    *t = tree.UpperBound();
    return true;
  }

  // PERF: Not sure we want to do all these calculations and
  // construct these objects for EVERY SAMPLE.
  vector<Controllers> NotesAt(int64 t) override {
    vector<IT::Interval *> ivals = tree.OverlappingPoint(t);
    vector<Controllers> ret;
    ret.reserve(ivals.size());
    for (int i = 0; i < ivals.size(); i++) {
      const IT::Interval *ival = ivals[i];
      // TODO: We could implement envelopes here (we have start and
      // end), but is it really the right place?
      Controllers c;
      c.Set(FREQUENCY, MidiFrequency(ival->t.note_index));
      
      double amp = ival->t.velocity / 127.0;

      // Fade in/out to avoid pops. Is this the right place to do this?
      static const int64 FADESAMPLES = 48LL;  // 1ms
      
      // TODO: Maybe sigmoid instead of triangle.
      if ((t - ival->start) < FADESAMPLES) {
	double f = (t - ival->start) / (double)FADESAMPLES;
	amp *= f;
      } else if (ival->end - t < FADESAMPLES) {
	double f = (ival->end - t) / (double)FADESAMPLES;
	amp *= f;
      }

      c.Set(AMPLITUDE, amp);
      // printf("f %f a %f\n", c.GetRequired(FREQUENCY),
      // c.GetRequired(AMPLITUDE));
      // printf("c: %d\n", c.size);
      ret.push_back(c);
    }
    // printf("Return NotesAt...\n");
    return ret;
  }

  IT tree;
  int instrument;
};

// upq is microseconds per quarternote
// divi is division
static int SptFromUpq(int divi, int upq) {
  constexpr double rate = SAMPLINGRATE;
  /* samples per tick is

     usec per tick      samples per usec
     (upq / divi)    *  (fps / 1000000)   */
  double fpq = (rate * upq) / (1000000.0 * divi);
  // XXX
  fprintf(stderr, "Samples per tick is now: %f\n", fpq);

  // Get the closest integer.
  return round(fpq);
}

// static
vector<MidiMusicLayer *> MidiMusicLayer::Create(const string &filename) {
  jdksmidi::MIDIFileReadStreamFile rs(filename.c_str());
  jdksmidi::MIDIMultiTrack tracks;
  jdksmidi::MIDIFileReadMultiTrack track_loader(&tracks);
  jdksmidi::MIDIFileRead reader(&rs, &track_loader);
  reader.Parse();

  // XXX these are hard coded! Get them from the file!
  // This is from the tempo.
  const int upq = 600000;
  // This just happens once.
  const int divi = 120;

  int spt = SptFromUpq(divi, upq);

  // XXX this needs to be deduced from the timecode / tempo
  auto SampleIndexFromClock = [spt](MIDIClockTime t) -> int64 {
    return t * spt;
  };

  vector<MidiMusicLayer *> layers;
  for (int i = 0; i < tracks.GetNumTracks(); i++) {
    MIDITrack *track = tracks.GetTrack(i);
    if (!track->IsTrackEmpty()) {
      track->SortEventsOrder();
      int removed = track->RemoveIdenticalEvents();
      if (removed > 0) {
	fprintf(stderr, "There were %d identical events, removed\n",
		removed);
      }

      // Pair of start time and velocity, but if velocity
      // is zero, then start time is ignored and it means
      // the note is currently off.
      vector<pair<int64, int>> notes_active(128, {0, 0});

      vector<MidiNote> notes_done;
      
      // Process each track into a MidiMusicLayer. We ignore
      // channels, assuming the track corresponds to a single
      // instrument. Polyphony is supported, but we also assume
      // a single note is on only once at a time.
      for (int e = 0; e < track->GetNumEvents(); e++) {
	const MIDITimedBigMessage *msg = track->GetEvent(e);
	int64 t = msg->GetTime();

	if (msg->ImplicitIsNoteOn()) {
	  int note = msg->GetNote();
	  if (note < 0 || note > 127) {
	    fprintf(stderr, "BAD NOTE: %d\n", note);
	    continue;
	  }
	  if (notes_active[note].second) {
	    fprintf(stderr, "Note on while on: %d\n", note);
	    continue;
	  }

	  notes_active[note] = { SampleIndexFromClock(t), 
				 msg->GetVelocity() };

	} else if (msg->ImplicitIsNoteOff()) {
		int note = msg->GetNote();
	  if (note < 0 || note > 127) {
	    fprintf(stderr, "BAD NOTE: %d\n", note);
	    continue;
	  }
	  if (!notes_active[note].second) {
	    fprintf(stderr, "Note off while off: %d\n", note);
	    continue;
	  }

	  MidiNote mn;
	  mn.start = notes_active[note].first;
	  mn.end = SampleIndexFromClock(t);
	  mn.payload.note_index = note;
	  mn.payload.velocity = notes_active[note].second;
	  notes_done.push_back(mn);

	  notes_active[note] = { 0, 0 };

	} else {
	  switch (msg->GetType()) {
	  case NOTE_OFF:
	    CHECK(!"impossible off");
	    break;
	  case NOTE_ON:
	    CHECK(!"impossible on");
	  break;
	  default:
	    // XXX don't print
	    DumpMIDITimedBigMessage(msg);	  
	  }
	}

      }

      fprintf(stderr, "At the end of track %d there were %lld notes.\n",
	      i,
	      notes_done.size());
      if (notes_done.size() > 0) {
	// XXX deduce the actual instrument.
	int instrument = 1;
	RealMML *layer = new RealMML(notes_done, instrument);
	
	layers.push_back(layer);
      }
    }
  }
  
  return layers;
}

