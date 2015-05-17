// TODO: There's a copy of this in cc-lib. Merge 'em.  2 Apr 2015

#ifndef __INTERVAL_TREE_H
#define __INTERVAL_TREE_H

#include <map>
#include <utility>
#include <vector>

// Return the midpoint of an interval. If it cannot be
// represented (e.g. integral interval (2,3]) then round
// down to the start.
template<class T>
struct IntervalDefaultBisect {
  T operator ()(const T &a, const T &b) {
    // XXX I think this may be wrong for negative numbers.
    return static_cast<T>((a + b) / 2);
  }
};

// TODO: Thread safety.
//
// An interval tree stores overlapping one-dimensional intervals in an
// efficient way, permitting O(log(n) + m) lookup (where n is the
// number intervals and m is the number of intervals in the response).
// One use would be storing the notes in song and then asking, at this
// moment in time, what notes are currently active?
//
// Idx must be a type with a comparison operators and efficient
// value semantics; int64 and double are good choices. If not numeric,
// then you also must provide a Bisect functor (see above) to split
// two indices down the middle.
template<class Idx, class T, class Bisect = IntervalDefaultBisect<Idx>>
struct IntervalTree {
  // Empty tree.
  IntervalTree();

  // TODO: Copy and move constructors, etc.

  // Although methods in here return non-const pointers to intervals,
  // the start and end indices should not be modified after insertion.
  struct Interval {
    // Half-open interval [start, end).
    // TODO: Possible to make that configurable?
    Idx start, end;
    T t;
    Interval(Idx start, Idx end, T t) : start(start), end(end), t(t) {}
  };

  ~IntervalTree();

  // Return all the intervals that overlap the point, in arbitrary
  // order.
  std::vector<Interval *> OverlappingPoint(Idx point) const {
    return OverlappingPointIt(point, root);
  }

  // TODO: OverlappingInterval!

  bool Empty() const { return root != NULL; }

  // Return the start index of the first interval, or Idx() if
  // the tree is empty.
  Idx LowerBound() const {
    bool has_idx = false;
    Idx lowest = Idx();
    for (Node *t = root; t != NULL; t = t->left) {
      // First interval might be in the overlapping set.
      // If it's non-empty, then the first one is the earliest.
      if (!t->by_begin.empty()) {
	if (!has_idx || t->by_begin.begin()->first < lowest) {
	  lowest = t->by_begin.begin()->first;
	  has_idx = true;
	}
      }
    }

    return lowest;
  }

  // Return the end index of the interval that ends last (which is not
  // included in that interval, as usual) in the tree, or Idx() if
  // the tree is empty.
  Idx UpperBound() const {
    bool has_idx = false;
    Idx highest = Idx();
    for (Node *t = root; t != NULL; t = t->right) {
      // Last interval might be in the overlapping set.
      // If it's non-empty, then the first one is the latest.
      if (!t->by_end.empty()) {
	// (Note reverse iterator.)
	if (!has_idx || highest < t->by_end.rbegin()->first) {
	  highest = t->by_end.rbegin()->first;
	  has_idx = true;
	}
      }
    }

    return highest;
  }

  // Returns a pointer to the interval, but it remains owned by
  // the tree.
  Interval *Insert(Idx start, Idx end, T t) {
    Interval *ret = new Interval(start, end, t);
    Node **tree = &root;
    while ((*tree) != NULL) {
      if (end < (*tree)->center) {
	// Entirely to the left.
	tree = &(*tree)->left;
      } else if ((*tree)->center < start) {
	// Entirely to the right.
	tree = &(*tree)->right;
      } else {
	// New interval overlaps the center. Just insert
	// it here.
	(*tree)->by_begin.insert(std::make_pair(start, ret));
	(*tree)->by_end.insert(std::make_pair(end, ret));
	// Done!
	return ret;
      }
    }

    // Got to an empty node. Create a new tree here.
    *tree = new Node;

    Idx center = Bisect()(start, end);
    (*tree)->center = center;
    (*tree)->left = NULL;
    (*tree)->right = NULL;
    // It contains only the new interval.
    (*tree)->by_begin.insert(std::make_pair(start, ret));
    (*tree)->by_end.insert(std::make_pair(end, ret));
    return ret;
  }

 private:

  struct Node {
    // Node in binary tree.
    Idx center;
    // Trees whose intervals that start entirely before/after
    // the center point. If NULL, then empty.
    Node *left, *right;
    // Intervals that overlap the center, sorted by begin point and
    // end point. Note that multiple intervals may start or end at the
    // exact same index. Each interval appears in both maps (and only
    // these maps). Both are sorted in increasing order, but we usually
    // do reverse iteration on by_end.
    std::multimap<Idx, Interval *> by_begin, by_end;
    ~Node();
  };

  // Recursive is most natural, but iterative is easier and
  // faster/safer in C++.
  static std::vector<Interval *> OverlappingPointIt(Idx point,
						    const Node *tree) {
    std::vector<Interval *> ret;
    while (tree != NULL) {
      if (point < tree->center) {
	// Since intervals in this node overlap the center, they
	// certainly end after the point. Return all the ones that
	// begin before the point (or on the point).

	for (auto it = tree->by_begin.begin(); 
	     it != tree->by_begin.end() && it->first <= point;
	     ++it) {
	  ret.push_back(it->second);
	}

	tree = tree->left;
      } else if (tree->center < point) {
	// Symetrically, intervals in this node begin before the
	// point. Return any that end (strictly) after the point.

	// (note this is a reverse iteration)
	for (auto it = tree->by_end.rbegin();
	     it != tree->by_end.rend() && point < it->first;
	     ++it) {
	  ret.push_back(it->second);
	}

	tree = tree->right;
      } else {
	// If point is exactly the center, then the overlapping
	// ones are it. Early exit.
	for (const auto &p : tree->by_begin) {
	  ret.push_back(p.second);
	}
	return ret;
      }
    }
    return ret;
  }

  // NULL means empty.
  Node *root;
 private:
  // TODO: Could implement these.
  IntervalTree(const IntervalTree &);
  IntervalTree &operator =(const IntervalTree &);
};

template<class Idx, class T, class B>
IntervalTree<Idx, T, B>::IntervalTree() : root(NULL) {}

template<class Idx, class T, class B>
IntervalTree<Idx, T, B>::~IntervalTree() {
  delete root;
}

template<class Idx, class T, class B>
IntervalTree<Idx, T, B>::Node::~Node() {
  delete left;
  delete right;
  left = NULL;
  right = NULL;
  // ONLY delete from the begin map. We own the intervals, but
  // the same set of pointers is in each map.
  for (auto &p : by_begin) {
    delete p.second;
  }
  by_begin.clear();
  by_end.clear();
}

#endif
