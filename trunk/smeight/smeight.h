
#ifndef __SMEIGHT_H
#define __SMEIGHT_H

#include <string>
#include <vector>
#include <map>
#include <cstdint>
#include <memory>

#include <thread>
#include <mutex>

using namespace std;

#include "../fceulib/types.h"
#include "../cc-lib/base/stringprintf.h"
#include "../cc-lib/base/logging.h"
#include "../cc-lib/threadutil.h"

#include "../cc-lib/stb_image_write.h"
#include "../fceulib/emulator.h"

// e.g. with C = map<int, string>. Third argument is the default.
template<class K, class C>
auto GetDefault(const C &container,
		const K &key,
		const decltype(container.find(key)->second) &def) ->
  decltype(container.find(key)->second) {
  auto it = container.find(key);
  if (it == container.end()) return def;
  return it->second;
}

#define NOT_COPYABLE(classname) \
  private: \
  classname(const classname &) = delete; \
  classname &operator =(const classname &) = delete

namespace internal {
template<class... Argtypes>
struct DisjointBitsC;

template<class T, class ...Argtypes>
struct DisjointBitsC<T, Argtypes...> {
  static constexpr bool F(uint64 used, T head, Argtypes... tail) {
    return !(used & head) &&
      DisjointBitsC<Argtypes...>::F(used | head, tail...);
  }
};

template<>
struct DisjointBitsC<> {
  static constexpr bool F(uint64 used_unused) {
    return true;
  }
};
}

// Compile-time check that the arguments don't have any overlapping
// bits; used for bitmasks. Assumes the width is no greater than
// uint64. Intended for static_assert.
template<class... Argtypes>
constexpr bool DisjointBits(Argtypes... a) {
  return internal::DisjointBitsC<Argtypes...>::F(0, a...);
}

template<int start, int end, class F>
struct For_ {
  static void Go(const F &f) {
    f(start);
    For_<start + 1, end, F>::Go(f);
  }
};

template<int basecase, class F>
struct For_<basecase, basecase, F> {
  static void Go(const F &f) {}
};

// Run the function on start, start+1, start+2, ..., up to but not
// including end.
template<int start, int end, class F>
inline void For(const F &f) {
  For_<start, end, F>::Go(f);
}

template<class T, class K>
bool ContainsKey(const T &t, const K &k) {
  return t.find(k) != t.end();
}




struct AngleRule {
  uint16 memory_location = 0xFFFF;
  uint8 value = 0;
  bool Match(const vector<uint8> &mem) {
    if (memory_location == 0xFFFF)
      return false;

    CHECK(memory_location < mem.size()) << memory_location;
    return mem[memory_location] == value;
  }
  bool Valid() const { return memory_location < 2048; }
};


// XXX Move to utilities
inline void SaveEmulatorImage(const Emulator *emu,
			      const string &filename) {
  vector<uint8> rgba = emu->GetImage();
  stbi_write_png(filename.c_str(),
		 256, 240, 4,
		 rgba.data(),
		 256 * 4);
  printf("Wrote %s.\n", filename.c_str());
}


#endif
