
#include "interval-cover.h"

#include <stdlib.h>
#include <set>
#include <vector>
#include <string>
#include <memory>

#include "../cc-lib/arcfour.h"
#include "base.h"

using namespace std;

// TODO: Use good logging package.
#define CHECK(condition) \
  while (!(condition)) {                                    \
    fprintf(stderr, "%s:%d. Check failed: %s",              \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

template<class T>
static void Shuffle(vector<T> *v) {
  static ArcFour rc("shuffler");
  for (int i = 0; i < v->size(); i++) {
    unsigned int h = 0;
    h = (h << 8) | rc.Byte();
    h = (h << 8) | rc.Byte();
    h = (h << 8) | rc.Byte();
    h = (h << 8) | rc.Byte();

    int j = h % v->size();
    if (i != j) {
      swap((*v)[i], (*v)[j]);
    }
  }
}

template<class T>
static bool ContainsKey(const set<T> &s, const T &k) {
  return s.find(k) != s.end();
}

int main(int argc, char *argv[]) {
  // Check that it compiles with some basic types.
  { IntervalCover<int> unused(0); (void)unused; }
  { IntervalCover<double> unused(1.0); (void)unused; }
  { IntervalCover<string> unused(""); (void)unused; }
  { IntervalCover<shared_ptr<int>> unused(nullptr); (void)unused; }

#if 0
  {
    // Empty tree.
    IntervalTree<double, Unit> empty;
    CHECK(empty.OverlappingPoint(0.0).empty());
    CHECK(empty.LowerBound() == 0.0);
    CHECK(empty.UpperBound() == 0.0);
  }

  {
    // Easy.
    IntervalTree<int, string> easy;
    easy.Insert(3, 5, "hello");
    easy.Insert(4, 7, "overlap");
    CHECK(easy.LowerBound() == 3);
    CHECK(easy.UpperBound() == 7);
  }

  typedef IntervalTree<double, string> IT;
  auto IsSameSet = [](const set<string> &expected,
		      const vector<IT::Interval *> &v) -> bool {
    if (expected.size() != v.size()) {
      printf("Expected %lld elements, got %lld\n",
	     expected.size(), v.size());
      return false;
    }
    CHECK(expected.size() == v.size());
    set<string> already;
    for (const IT::Interval *ival : v) {
      // No duplicates.
      if (ContainsKey(already, ival->t)) {
	printf("Duplicate key: %s\n", ival->t.c_str());
	return false;
      }
      already.insert(ival->t);
      if (!ContainsKey(expected, ival->t)) {
	printf("Key present that shouldn't be: %s\n", ival->t.c_str());
	return false;
      }
    }
    return true;
  };

  // .0 .1 .2 .3 .4 .5 .6 .7 .8 .9 1.0
  //  |  |  |  |  |  |  |  |  |  |  |
  //     aaaaaa      bbb
  //     ccccccddd            h
  //     eeeeee
  //  fffffffffffffffffffffffffff
  //        g
  vector<Insertable> data = {
    {0.1, 0.3, "a"},
    {0.5, 0.6, "b"},
    {0.1, 0.3, "c"},
    {0.3, 0.4, "d"},
    {0.1, 0.3, "e"},
    {0.0, 0.9, "f"},
    {0.2, 0.2, "g"},
    {0.8, 0.8, "h"},
  };

  // Keep doing it with random insertion order.
  for (int round = 0; round < 1000; round++) {
    // Now with some real data.
    IntervalTree<double, string> tree;
    for (const Insertable &i : data) {
      tree.Insert(i.a, i.b, i.c);
    }

    CHECK(tree.OverlappingPoint(-5.0).empty());
    CHECK(tree.OverlappingPoint(2.0).empty());
    CHECK(IsSameSet({"b", "f"}, tree.OverlappingPoint(.5)));
    CHECK(IsSameSet({"b", "f"}, tree.OverlappingPoint(.51)));
    CHECK(IsSameSet({"f"}, tree.OverlappingPoint(0.499)));

    CHECK(IsSameSet({"f", "h"}, tree.OverlappingPoint(0.8)));
    CHECK(IsSameSet({"d", "f"}, tree.OverlappingPoint(0.3)));
    CHECK(IsSameSet({"a", "c", "e", "f", "g"},
		    tree.OverlappingPoint(0.2)));
    CHECK(IsSameSet({"a", "c", "e", "f"},
		    tree.OverlappingPoint(0.1)));

    CHECK(tree.LowerBound() == 0.0);
    CHECK(tree.UpperBound() == 0.9);

    Shuffle(&data);
  }
#endif

  printf("IntervalCover tests OK.\n");
  return 0;
}
