// Stuff (macros) that should be included everywhere.
// TODO: Move to cc-lib, minimize the includes, and include it
// anywhere we want.

#ifndef __BASE_H
#define __BASE_H

#include <vector>
#include <string>
#include <utility>
#include <cstdint>


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

#define UNIMPLEMENTED(message) \
  do { fprintf(stderr, "%s:%s:%d. Unimplemented: %s\n", \
	       __FILE__, __func__, __LINE__, #message); \
    abort();						\
  } while (0)

// TODO: Use good logging package, or at least make this
// return a version of cerr that aborts after outputting
// the message, so we can do CHECK(cond) << "helpful message";.
#define CHECK(condition) \
  while (!(condition)) {                                    \
    fprintf(stderr, "%s:%s:%d. Check failed: %s\n",	    \
            __FILE__, __func__, __LINE__, #condition        \
            );                                              \
    abort();                                                \
  }

// TODO: Make debug mode. For now these are just marked as
// paranoid checks so that we can make them debug-only later
// to improve performance.
#define DCHECK(condition) CHECK(condition)

// TODO: Move constructors too? Are they defined by default?
#define NOT_COPYABLE(classname) \
  private: \
  classname(const classname &) = delete; \
  classname &operator =(const classname &) = delete

// TODO: Possible to verify there are no members?
#define ALL_STATIC(classname) \
  private: \
  classname() = delete; \
  NOT_COPYABLE(classname)

using namespace std;

// Can probably retire this; little chance that we compile with
// MSVC any more.
#ifdef COMPILER_MSVC
// http://msdn.microsoft.com/en-us/library/b0084kay(v=vs.71).aspx
#ifndef _CHAR_UNSIGNED
#error Please compile with /J for unsigned chars!
#endif
#endif

// Generally we just want reliable and portable names for specific
// word sizes. C++11 actually gives these to us now; no more
// "well, long long is at least big enough to hold 64 bits, and
// chars might actually be 9 bits, etc.". 

typedef uint8_t  uint8;
typedef int16_t  int16;
typedef uint16_t uint16;
typedef int32_t  int32;
typedef uint32_t uint32;
typedef int64_t  int64;
typedef uint64_t uint64;

// I think that the standard now REQUIRES the following assertions to
// succeed. But if some shenanigans are going on, let's get out of
// here.
static_assert(UINT8_MAX == 255, "Want 8-bit chars.");
static_assert(sizeof(int16) == 2, "16 bits is two bytes.");
static_assert(sizeof(uint16) == 2, "16 bits is two bytes.");

static_assert(sizeof(int32) == 4, "32 bits is four bytes.");
static_assert(sizeof(uint32) == 4, "32 bits is four bytes.");

static_assert(sizeof(int64) == 8, "64 bits is eight bytes.");
static_assert(sizeof(uint64) == 8, "64 bits is eight bytes.");

#endif
