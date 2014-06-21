// Local libraries and wrappers for programming with mutexes (etc.)
// in 10goto20.
//
// TODO: Consider std::thread and std::mutex instead. Ideally, we
// should use SDL threads only in this file, so that we can port
// to c++11 later if it's working.


#ifndef __CONCURRENCY_H
#define __CONCURRENCY_H

#include "base.h"

#include "SDL.h"
#include "SDL_thread.h"
#include "SDL_mutex.h"

// Wraps an SDL_mutex pointer. 
struct Mutex {
  void Lock() { 
    SDL_LockMutex(sdl_mutex);
  }

  void Unlock() {
    SDL_UnlockMutex(sdl_mutex);
  }

  // Be careful -- creating a static Mutex is probably unsafe
  // because CreateMutex probably depends on initialization
  // that happens in SDL_Init and the wrapper around main.
  // Instead you can use the separate STATIC_UNINITIALIZED
  // constructor and explicitly initialize.
  //
  // TODO: It would maybe be possible to have the static
  // versions register themselves in a list and then initialized
  // once on startup, right after SDL_Init. Right now we don't
  // have a lot of static mutexes in 10goto20 though.
  Mutex() {
    Init();
  }

  enum Uninitialized {
    STATIC_UNINITIALIZED,
  };

  explicit Mutex(Uninitialized u) {
    // nothing...
  }

  void Init() {
    CHECK(sdl_mutex == nullptr);
    sdl_mutex = SDL_CreateMutex();
  }

  ~Mutex() {
    CHECK(sdl_mutex != nullptr);
    SDL_DestroyMutex(sdl_mutex);
  }

  bool Initialized() {
    return sdl_mutex != nullptr;
  }

  SDL_mutex *sdl_mutex = nullptr;
 private:
  Mutex(const Mutex &) = delete;
  Mutex &operator =(const Mutex &) = delete;
};

struct MutexLock {
  explicit MutexLock(Mutex *m) : m(m) {
    m->Lock();
  }
  ~MutexLock() {
    m->Unlock();
  }
 private:
  MutexLock(const MutexLock &) = delete;
  MutexLock &operator =(const MutexLock &) = delete;
  Mutex *m;
};

#endif
