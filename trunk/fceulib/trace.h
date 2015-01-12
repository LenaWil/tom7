#ifndef __TRACE_H
#define __TRACE_H

#include <string>
#include <vector>
#include <cstdint>

// This is a facility only used for debugging fceulib regressions. The
// idea is that we see a change in the memory checksum for a game after
// some change, but we don't know what caused it. What we do is install
// trace commands (or use the ones already inserted) in order to generate
// a history of execution that should agree byte-for-byte between two
// versions that bookend the regression. Diffing the trace lets us semi-
// automatically narrow in on the moment that they diverge.

struct Traces {
  // Value semantics; when this is running, all performance bets are off.
  enum TraceType {
    // Free-form string.
    STRING = 1,
    // Chunk of memory (bytes) of any size.
    MEMORY = 2,
    // Used for anything that can fit in a uint64.
    NUMBER = 3,
  };

  struct Trace {
    explicit Trace(TraceType type) : type(type) { }
    TraceType type;
    std::string data_string;
    std::vector<uint8_t> data_memory;
    uint64_t data_number = 0ULL;
  };

  static bool Equal(const Trace &l, const Trace &r);

  static std::string Difference(const Trace &l, const Trace &r);
  static std::string LineString(const Trace &t);

  // Adds a trace like printf.
  // void TraceF(const char *fmt, ...);
  void TraceString(const std::string &s);
  void TraceMemory(const std::vector<uint8_t> &v);
  void TraceArray(const uint8_t *p, int size);
  void TraceNumber(uint64_t n);

  // std::vector<Trace> traces;
  FILE *fp = nullptr;

  // Write to the file pointer. Not thread-safe.
  void Write(const Trace &t);

  // Note that this opens the file (clobbering it).
  Traces();

  // To compare traces, use this.
  static std::vector<Trace> ReadFromFile(const std::string &filename);
};

#endif  // __TRACE_H
