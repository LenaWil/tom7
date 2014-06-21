// Stuff (macros) that should be included everywhere.

#ifndef __BASE_H
#define __BASE_H

#include <vector>
#include <string>
#include <utility>

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
    fprintf(stderr, "%s:%d. Check failed: %s",              \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

#define NOT_COPYABLE(classname) \
  private: \
  classname(const classname &) = delete; \
  classname &operator =(const classname &) = delete

using namespace std;

// Can probably retire this; little chance that we compile with
// MSVC any more.
#ifdef COMPILER_MSVC
// http://msdn.microsoft.com/en-us/library/b0084kay(v=vs.71).aspx
#ifndef _CHAR_UNSIGNED
#error Please compile with /J for unsigned chars!
#endif
#endif

typedef Uint8  uint8;
typedef Sint16 int16;
typedef Uint16 uint16;
typedef Sint64 int64;
typedef Uint64 uint64;

#endif
