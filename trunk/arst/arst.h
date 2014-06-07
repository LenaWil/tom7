
#ifndef __ARST_H
#define __ARST_H

#include "../cc-lib/util.h"
#include "../cc-lib/heap.h"
#include "../cc-lib/stb_image.h"

#include <vector>
#include <string>

#include "../cc-lib/base/stringprintf.h"
#include "SDL.h"
#include "../cc-lib/sdl/sdlutil.h"

#ifdef __GNUC__
#include <ext/hash_map>
#include <ext/hash_set>
#else
#include <hash_map>
#include <hash_set>
#endif

#define DEBUGGING 0

#define SWAB 1

#ifdef __GNUC__
namespace std {
using namespace __gnu_cxx;
}

// Needed on cygwin, at least. Maybe not all gnuc?
namespace __gnu_cxx {
template<>
struct hash<unsigned long long> {
  size_t operator ()(const unsigned long long &x) const {
    return x;
  }
};
}
#endif

using namespace std;

// TODO: Use good logging package.
#define CHECK(condition) \
  while (!(condition)) {                                    \
    fprintf(stderr, "%s:%d. Check failed: %s\n",            \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

#define DCHECK(condition) \
  while (DEBUGGING && !(condition)) {                       \
    fprintf(stderr, "%s:%d. DCheck failed: %s\n",           \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

#define NOT_COPYABLE(classname) \
  private: \
  classname(const classname &); \
  classname &operator =(const classname &)

// assumes RGBA, surfaces exactly the same size, etc.
inline void CopyRGBA(const vector<uint8> &rgba, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 *p = (Uint8 *)surface->pixels;
  memcpy(p, &rgba[0], surface->w * surface->h * 4);
}

inline void UncopyRGBA(const SDL_Surface *surface, vector<uint8> *rgba) {
  const Uint8 *p = (const Uint8 *)surface->pixels;
  int num = surface->w * surface->h * 4;
  rgba->resize(num);
  memcpy(&(*rgba)[0], p, num);
}

inline const Uint8 *SurfaceRGBA(const SDL_Surface *surface) {
  return (Uint8 *)surface->pixels;
}

inline void CopyRGBA2x(const vector<uint8> &rgba, SDL_Surface *surface) {
  Uint8 *p = (Uint8 *)surface->pixels;
  const int width = surface->w;
  CHECK((width & 1) == 0);
  const int halfwidth = width >> 1;
  const int height = surface->h;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int idx = (y * width + x) * 4;
      int hidx = ((y >> 1) * halfwidth + (x >> 1)) * 4;
      #if SWAB
      p[idx + 0] = rgba[hidx + 2];
      p[idx + 1] = rgba[hidx + 1];
      p[idx + 2] = rgba[hidx + 0];
      p[idx + 3] = rgba[hidx + 3];
      #else
      p[idx + 0] = rgba[hidx + 0];
      p[idx + 1] = rgba[hidx + 1];
      p[idx + 2] = rgba[hidx + 2];
      p[idx + 3] = rgba[hidx + 3];
      #endif
    }
  }
}

struct Graphic2x {
  // From a PNG file.
  explicit Graphic2x(const vector<uint8> &bytes) {
    int bpp;
    uint8 *stb_rgba = stbi_load_from_memory(&bytes[0], bytes.size(),
                                            &width, &height, &bpp, 4);
    CHECK(stb_rgba);
    for (int i = 0; i < width * height * 4; i++) {
      rgba.push_back(stb_rgba[i]);
    }
    stbi_image_free(stb_rgba);
    if (DEBUGGING)
      fprintf(stderr, "image is %dx%d @%dbpp = %lld bytes\n",
              width, height, bpp,
              rgba.size());

    surf = sdlutil::makesurface(width * 2, height * 2, true);
    CHECK(surf);
    CopyRGBA2x(rgba, surf);
  }

  void BlitTo(SDL_Surface *surfto, int x, int y) {
    sdlutil::blitall(surf, surfto, x, y);
  }

  ~Graphic2x() {
    SDL_FreeSurface(surf);
  }

  int width, height;
  vector<uint8> rgba;
  SDL_Surface *surf;
 private:
  NOT_COPYABLE(Graphic2x);
};

// T must be copyable.
template<class T>
T AtomicRead(T *loc, SDL_mutex *m) {
  SDL_LockMutex(m);
  T val = *loc;
  SDL_UnlockMutex(m);
  return val;
}

template<class T>
void AtomicWrite(T *loc, T value, SDL_mutex *m) {
  SDL_LockMutex(m);
  *loc = value;
  SDL_UnlockMutex(m);
}

struct MutexLock {
  explicit MutexLock(SDL_mutex *m) : m(m) { SDL_LockMutex(m); }
  ~MutexLock() { SDL_UnlockMutex(m); }
  SDL_mutex *m;
 private:
  NOT_COPYABLE(MutexLock);
};


#endif
