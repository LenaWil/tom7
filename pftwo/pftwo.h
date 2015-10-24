
#ifndef __PFTWO_H
#define __PFTWO_H

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

#if 0

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
struct hash<unsigned long long> {
  size_t operator ()(const unsigned long long &x) const {
    return x;
  }
};
}
#endif

#endif

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

#endif
