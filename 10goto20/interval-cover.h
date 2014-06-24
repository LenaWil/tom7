
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
    Data data;
    Span(int64 s, int64 e, Data d) : start(s), end(e), data(d) {}
  };

  // Create an empty interval cover, where the entire range is
  // the default value.
  IntervalCover(Data def);

  // Get the span that covers the specific point. There is always
  // such a span.
  Span GetPoint(int64 pt) const;

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
  // (i.e., where Last(p) returns true). (This includes
  // LLONG_MAX - 1, which must be in the last interval.)
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
  // Make a Span by looking at the next entry in the map to
  // compute the end. The iterator may not denote spans.end().
  Span MakeSpan(typename map<int64, Data>::const_iterator &it) const;

  // Takes an iterator to an entry in the map (not spans.end())
  // and fixes invariants to the right. In particular, it might
  // need to be
  //   - merged with the next entry, for it has the same data
  //   - have the next entry deleted, for it is empty
  // The supplied iterator will not be invalidated or modified,
  // but we may invalidate it->next() (if it exists).
  void FixupRight(typename map<int64, Data>::iterator &it);
  // Same, but to the left. Can invalidate it itself, because
  // if it has the same data as the one to its left, we merge
  // to the left.
  void FixupLeft(typename map<int64, Data>::iterator &it);

  typename map<int64, Data>::iterator GetInterval(int64 pt);

  // Takes an iterator to an entry in the map (not spans.end())
  // and fixes the invariant that no span may be empty, by 
  // deleting this interval if it is empty. This may create a
  // new invariant violation because it may put two intervals
  // in contact that have the same data.
  //
  // If the entry was deleted, then the argument iterator is now
  // invalid. The function returns true, and sets the out iterator
  // to the next element after it (or spans.end() if it was the last).
  bool FixupMaybeEmpty(const typename map<int64, Data>::const_iterator &it,
		       typename map<int64, Data>::iterator &out);

  // Actual representation is an stl map with some invariants.
  map<int64, Data> spans;

  // TODO: Actually, this is probably copyable, since we don't claim
  // to keep the Data from being copied, and map has value semantics.
  NOT_COPYABLE(IntervalCover);
};

template<class D>
bool IntervalCover<D>::FixupMaybeEmpty(
    const typename map<int64, D>::const_iterator &it,
    typename map<int64, D>::iterator &out) {
  CHECK(it != spans.end());
  auto next = it.next();
  if (next == spans.end()) {
    // The final interval is only empty if it starts at the maximum
    // value:
    // [LLONG_MAX - 1, LLONG_MAX) is a legal, non-empty interval,
    // but [LLONG_MAX, LLONG_MAX) is not.
    if (it->first == LLONG_MAX) {
      out = spans.erase(it);
      return true;
    }
  } else {
    int64 end = next->start;
    if (it->start == end) {
      out = spans.erase(it);
      return true;
    }
  }
  return false;
}

template<class D>
void IntervalCover<D>::FixupLeft(typename map<int64, D>::iterator &it) {
  if (it == spans.begin()) {
    // Invariant.
    CHECK(it->first == LLONG_MIN);
    return;
  } else {
    auto prev = std::prev(it);
    if (prev->second == it->second) {
      spans.erase(it);
      return;
    }
  }

  // XXX should delete empty left span? Do the same thing as in FixupRight.
  typename map<int64, D>::iterator unused;
  FixupMaybeEmpty(prev, unused);
  return;
}

template<class D>
void IntervalCover<D>::FixupRight(typename map<int64, D>::iterator &it) {
  CHECK(it != spans.end());
  auto next = std::next(it);
  if (next == spans.end()) {
    // If this is the last entry, then we are done; there's nothing
    // to the right to be fixed up.
    return;
  } else {

    if (it->second == next->second) {
      // The two need to be merged. This can be done by simply
      // removing the span to the right. We don't need to merge
      // with the one after that, because it can't have the
      // same key as this one (by invariant, transitivity of ==).
      spans.erase(next);
      // And we are done.
      return;
    }

    // XXX is this the right place to be deleting empty intervals
    // to the right? Maybe it should just be explicit in places
    // that might need it (it can only happen by modifying start
    // of the later intervals, so at that point you have the
    // interval anyway.)
    // Otherwise, maybe the next one is empty?
    typename map<int64, D>::iterator unused;
    FixupMaybeEmpty(next, unused);
    // Note next is now invalid. But anyway, we're done.
    return;
  }
}


// Template implementations follow.

template<class D>
auto IntervalCover<D>::GetInterval(int64 pt) ->
  typename map<int64, D>::iterator {
  // Find the interval that 'start' is within. We'll modify this
  // interval.
  auto it = spans.upper_bound(pt);
  // Impossible; first interval starts at LLONG_MIN.
  CHECK(it != spans.begin());
  --it;
  return it;
}

template<class D>
IntervalCover<D>::IntervalCover(D d) : spans { { INT64_MIN, d } } {}

template<class D>
auto IntervalCover<D>::First() const -> Span {
  CHECK(!spans.empty());
  return *spans.begin();
}

template<class D>
auto IntervalCover<D>::Next(int64 pt) const -> Span {
  auto it = spans.upper_bound(pt);
  CHECK(it != spans.end());
  return MakeSpan(it);
}

template<class D>
auto IntervalCover<D>::MakeSpan(
    typename map<int64, D>::const_iterator &it) const -> Span {
  typename map<int64, D>::const_iterator next = std::next(it);
  if (next == spans.end()) {
    return Span(it->first, LLONG_MAX, it->second);
  } else {
    return Span(it->first, next->first, it->second);
  }
}

template<class D>
auto IntervalCover<D>::GetPoint(int64 pt) const -> Span {
  // Gets the first span that starts strictly after the point.
  typename map<int64, D>::const_iterator it = spans.upper_bound(pt);
  // Should never happen, because the first interval starts
  // at LLONG_MIN.
  CHECK(it != spans.begin());
  --it;
  return MakeSpan(it);
}

template<class D>
void IntervalCover<D>::SetSpan(int64 start, int64 end, D d) {
  // Interval must be legal.
  CHECK(start <= end);

  // Don't do anything for empty intervals.
  if (start == end)
    return;

  auto it = GetInterval(start);
  // XXX use SplitRight,
  // delete any intervals that are entirely within [start,end)
  // update the start of the interval that partially overlaps
  // (if any).

}


template<class D>
void IntervalCover<D>::SplitRight(int64 pt, D rhs) {
  // Find the interval in which pt lies.
  auto it = GetInterval(pt);

  // Avoid doing any work if we're splitting but would have to
  // merge back together immediately.
  if (it->second == rhs)
    return;

  // And if we're asking to split the interval exactly on
  // its start point, just replace the data.
  if (it->first == pt) {
    it->second = rhs;
    return;
  }

  // If there's a next interval and the new data is the same
  // as the next, then another simplification:
  auto next = std::next(it);
  if (next != spans.end() && next->second == rhs) {
    // This would be a bug. Make sure we're moving the next's start
    // to the left. We can't be creating an empty interval because
    // we already ensured that it->first < pt.
    CHECK(pt < next->first);
    // We can't actually modify the key in std::map (we'd like to
    // set it to pt, which would maintain the order invariant),
    // but erasing and inserting with a hint is amortized constant
    // time:
    auto nextnext = spans.erase(next);
    spans.insert(nextnext, make_pair(pt, rhs));
    return;
  }

  // In this case, we just need to insert a new interval, which
  // is guaranteed to be non-empty and have distinct data to
  // the left and right.
  //
  // In C++11, hint is the element *following* where this one
  // would go.
  spans.insert(next, make_pair(pt, rhs));
}

#endif
