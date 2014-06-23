
// Defines an interval cover, which is a sparse set of non-overlapping
// spans:
//
//   - Spans are defined as [start, end) as elsewhere.
//   - The indices are int64; this could be templated on smaller
//     integer types, but that doesn't seem likely to be useful
//     in 10goto20.
//   - Sparse meaning that the cover describes the entire space
//     from LLONG_MIN to LLONG_MAX - 1, including explicit gaps.
//   - Takes space proportional to the number of intervals.
//   - Most operations are logarithmic in the number of intervals.
//
// Not thread safe; clients should manage mutual exclusion.

#ifndef __INTERVAL_COVER
#define __INTERVAL_COVER

#include <vector>
#include <map>
#include <cstdint>

#include "base.h"

// Data must have value semantics and is copied willy-nilly.
// It must also have an equivalence relation ==.
// If it's some simple data like int or bool, you're all set.
// If it's a pointer, you should use shared_ptr<T>; the
// default will then be an empty shared pointer ("null"). Raw
// pointers should be avoided, because various operations can
// duplicate Data or drop them (see below).
//
// TODO: Can we do without Default and instead just pass it
// as a constructor argument?
// TODO: For shared_ptr is this even ok? Do we really want
// to use the same empty shared pointer everywhere? (What if
// someone sets it?)
//
// Two adjacent intervals (no gap) will always have different Data
// values, and the operations below automatically merge adjacent
// intevals to ensure this. Empty intervals (start == end) are
// discarded, since they span no points.
template<class Data>
struct IntervalCover {
  struct Span {
    int64 start;
    // One after the end.
    int64 end;
    Data d;
  };

  // Create an empty interval cover, where the entire range is
  // the default value.
  IntervalCover(Data def);

  // Get the span that covers the specific point. There is always
  // such a span.
  Span GetPoint(int64 pt);

  // Split at the point. The right-hand-side of the split gets
  // the supplied data, and the left-hand retains the existing
  // data. (Note that splitting can produce empty intervals,
  // which are then eliminated, or if rhs equals the existing
  // data, the split has no effect because the pieces are
  // instantly merged together again.)
  void SplitRight(int64 pt, Data rhs);

  // Set the supplied span, overwriting anything underneath.
  // Might still merge with adjacent intervals, of course.
  void SetSpan(int64 start, int64 end, Data d);

  // Get the very first span.
  Span First() const;

  // Returns true if this span is the last one.
  bool IsLast(int64 pt) const;

  // Get the span that starts strictly after this point.
  // May not be called for any point within the last span
  // (i.e., where Last(p) returns true).
  // To iterate through spans,
  //
  // for (Span s = ic.First();
  //      !ic.IsLast(s.start);
  //      s = ic.Next(s.start)) { ... }
  // TODO: Make iterator version, probably for ranges? It
  // can be more efficient, too, if we keep the underlying
  // map iterator.
  Span Next(int64 pt) const;

 private:
  // Actual representation is an stl map with some invariants.
  map<int64, Data> spans;
};

template<class D>
IntervalCover<D>::IntervalCover(D d) : spans { { INT64_MIN, d } } {}

template<class D>
auto IntervalCover<D>::First() const -> Span {
  CHECK(!spans.empty());
  return *spans.begin();
}

// Template implementations follow.

template<class D>
void IntervalCover<D>::SplitRight(int64 pt, D rhs) {
  // If rhs == existing data, do nothing.
}

#endif
