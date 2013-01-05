
/* Basics to be included by any .cc file. */

#ifndef __10GOTO20_H
#define __10GOTO20_H

#include "SDL.h"
#include "SDL_thread.h"
#include "sdl/sdlutil.h"
#include "math.h"
#include <time.h>

#ifdef __GNUC__
#include <ext/hash_map>
#include <ext/hash_set>
#else
#include <hash_map>
#include <hash_set>
#endif

#ifdef __GNUC__
namespace std {
using namespace __gnu_cxx;
}

// Needed on cygwin, at least. Maybe not all gnuc?
namespace __gnu_cxx {
template<>
struct hash< unsigned long long > {
  size_t operator()( const unsigned long long& x ) const {
    return x;
  }
};
}
#endif

// TODO: Use good logging package.
#define CHECK(condition) \
  while (!(condition)) {                                    \
    fprintf(stderr, "%s:%d. Check failed: "                 \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

#define NOT_COPYABLE(classname) \
  private: \
  classname(const classname &); \
  classname &operator =(const classname &)

using namespace std;

#ifdef COMPILER_MSVC
// http://msdn.microsoft.com/en-us/library/b0084kay(v=vs.71).aspx
#ifndef _CHAR_UNSIGNED
#error Please compile with /J for unsigned chars!
#endif
#endif

// Local utilities

// (includes go here)

typedef Sint64 int64;
typedef Uint64 uint64;

// XXX more digits?
#define PI 3.141592653589
#define TWOPI 6.28318530718

#endif
