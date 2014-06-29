// Types etc. for the internal notion of revision. Whenever the song is
// modified, we increase the global revision number. Each moment in each
// layer (e.g. each sample) also knows its current revision; this lets
// us know whether the sample is up to date. Of course, we typically
// don't want to re-render the whole song just because one note changed
// in one place. So we also keep track of the last time the value changed.

#ifndef __REVISION_H
#define __REVISION_H

#include "base.h"

#if 0
// Small POD type 
struct Revision {
  // If 
  int64 current_revision = NEVER;
  int64 last_changed = NEVER;

  Revision(int64 cur, int64 last) : current_revision(cur), 
				    last_changed(last) {}
};
#endif

typedef int64 Revision;

// Keeps track of the global revision number, plus some utilities.
// Internally synchronized and thread-safe.
struct Revisions {
  // Initial value for current_revision. It's zero, before any
  // valid revision (on startup, the global revision will be 1 or
  // higher).
  static constexpr Revision NEVER = 0LL;

  // Must call this from the main thread before using anything else.
  static void Init();

  // Get the current revision. The revision number will only increase.
  static Revision GetRevision();

  // Increment the current revision and return its value. As with
  // GetRevision, the value is only guaranteed to be a lower bound
  // on the real current revision, since other threads may immediately
  // increment.
  static Revision NextRevision();

  ALL_STATIC(Revisions);
};

#endif
