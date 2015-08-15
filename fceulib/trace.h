#ifndef __TRACE_H
#define __TRACE_H

#include <string>
#include <vector>
#include <cstdint>
#include <cstdlib>

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

  // Tracing starts enabled. If temporarily disabled, traces
  // are discarded instead of being written to disk. However,
  // tracing can still be expensive, so globally disabling
  // tracing is done via macros in tracing.h.
  void SetEnabled(bool);
  bool IsEnabled() const;
  
  // Adds a trace like printf.
  // void TraceF(const char *fmt, ...);
  void TraceString(const std::string &s);
  void TraceMemory(const std::vector<uint8_t> &v);
  void TraceArray(const uint8_t *p, int size);
  void TraceNumber(uint64_t n);

  // Write to the file pointer. Not thread-safe.
  void Write(const Trace &t);

  // Switches to a new trace file, closing the old one. This is useful
  // when you are tracing two events within the same instance (that
  // should be the same, like replaying from a save-state) rather than
  // two different versions of the program to track down a regression.
  void SwitchTraceFile(const std::string &s);

  // Note that this opens the file (clobbering it).
  Traces();

  // To compare traces, use this.
  static std::vector<Trace> ReadFromFile(const std::string &filename);

 private:
  bool enabled = true;
  FILE *fp = nullptr;
};

#endif  // __TRACE_H
