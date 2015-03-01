
#ifndef __THREADUTIL_H
#define __THREADUTIL_H

#include <thread>
#include <mutex>

#include "mingw.thread.h"
#include "mingw.mutex.h"
// ugh, conflict...
#undef ARRAYSIZE

// Do progress meter.

// TODO: Make these functions take a "callable" template param F, rather
// than requiring std::function.

// Run the function f on each element of vec in parallel, with its
// index. The caller must of course synchronize any accesses to shared
// data structures. Return value of function is ignored.
template<class T>
void ParallelAppi(const vector<T> &vec, 
		  std::function<void(int i, const T&)> &f,
		  int max_concurrency) {
  std::mutex index_m;
  int next_index = 0;
  
  // Thread applies f repeatedly until there are no more indices.
  // PERF: Can just start each thread knowing its start index, and avoid
  // the synchronization overhead at startup.
  auto th = [&index_m, &next_index, &vec, &f]() {
    for (;;) {
      index_m.lock();
      if (next_index == vec.size()) {
	// All done. Don't increment counter so that other threads can
	// notice this too.
	index_m.unlock();
	return;
      }
      int my_index = next_index++;
      index_m.unlock();

      // Do work, not holding mutex.
      (void)f(my_index, vec[my_index]);
    }
  };

  vector<std::thread> threads;
  threads.reserve(max_concurrency);
  for (int i = 0; i < max_concurrency; i++) {
    threads.emplace_back(th);
  }
  // Now just wait for them all to finish.
  for (std::thread &t : threads) t.join();
}

// Same, but the typical case that the index is not needed.
template<class T>
void ParallelApp(const vector<T> &vec, 
		 std::function<void(const T&)> &f,
		 int max_concurrency) {
  std::function<void(int, const T &)> ff =
    [&f](int i_unused, const T &arg) { return f(arg); };
  ParallelAppi(vec, ff, max_concurrency);
}

// F needs to be callable (std::function or lambda) and thread safe. It returns R,
// which must have a default constructor, and this will only be efficient if it
// has move semantics as well.
template<class T, class F>
auto ParallelMap(const vector<T> &vec,
		 const F &f,
		 int max_concurrency) -> vector<decltype(f(vec.front()))> {
  using R = decltype(f(vec.front()));
  // Needed?
  // std::mutex out_m;
  vector<R> result;
  result.resize(vec.size());

  // Not sure if C++11 makes thread safety guarantees about vector::operator[], but
  // if we have a data pointer then we can be confident of having one writer to each
  // slot.
  R *data = result.data();
  std::function<void(int, const T &)> run_write = [data, &f](int idx, const T &arg) -> void {
    data[idx] = f(arg);
  };
  ParallelAppi(vec, run_write, max_concurrency);
  return result;
}

struct MutexLock {
  explicit MutexLock(std::mutex *m) : m(m) { m->lock(); }
  ~MutexLock() { m->unlock(); }
  std::mutex *m;
};


#endif
