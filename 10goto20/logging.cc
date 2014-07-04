
// NOTE: Avoid including logging.h first, since it redefines macros
// like CHECK from base.h. But we don't want things we depend on (e.g.
// Mutex::Init) to be calling logging.h macros!

#include "concurrency.h"
#include "10goto20.h"

#include "logging.h"

static Mutex mutex(Mutex::STATIC_UNINITIALIZED);

// static
void Logging::Init() {
  mutex.Init();
}

void Logging::GlobalLock() {
  mutex.Lock();
}

void Logging::GlobalUnlock() {
  mutex.Unlock();
}

int lprintf(const char *fmt, ...) {
  va_list arglist;
  MutexLock ml(&mutex);
  fflush(stdout);
  va_start(arglist, fmt);
  int ret = vprintf(fmt, arglist);
  va_end(arglist);
  fflush(stdout);
  return ret;
}
