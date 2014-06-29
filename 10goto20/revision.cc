
#include "revision.h"

#include "10goto20.h"
#include "concurrency.h"

// static
constexpr Revision Revisions::NEVER;



static Mutex mutex(Mutex::STATIC_UNINITIALIZED);
static Revision current_revision = 1LL;

// static 
Revision Revisions::GetRevision() {
  MutexLock ml(&mutex);
  return current_revision;
}

// static
Revision Revisions::NextRevision() {
  MutexLock ml(&mutex);
  current_revision++;
  return current_revision;
}

// static
void Revisions::Init() {
  CHECK(!mutex.Initialized());
  mutex.Init();
  CHECK(mutex.Initialized());
  CHECK(current_revision == 1LL);
}

