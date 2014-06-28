
#include "interval-cover.h"

#include <stdlib.h>
#include <set>
#include <vector>
#include <string>
#include <memory>
#include <iostream>

#include "../cc-lib/arcfour.h"
#include "base.h"
#include "gtest/gtest.h"
#include "base/stringprintf.h"

using namespace std;
using namespace testing;

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

#if 0
template<class T>
ostream &operator <<(ostream &os, const IntervalCover<string>::Span &span) {
  return os << "[" << span.start << ", \"" << span.data << "\"" 
	    << span.end << ")";
}
#endif

string SpanString(const IntervalCover<string>::Span &span) {
  string st = (span.start == LLONG_MIN) ? "MIN" : 
    StringPrintf("%lld", span.start);
  string en = (span.end == LLONG_MAX) ? "MAX" : 
    StringPrintf("%lld", span.end);
  return StringPrintf("[%s, \"%s\", %s)",
		      st.c_str(), span.data.c_str(), en.c_str());
}

int main(int argc, char *argv[]) {
  // Check that it compiles with some basic types.
  { IntervalCover<int> unused(0); (void)unused; }
  { IntervalCover<double> unused(1.0); (void)unused; }
  { IntervalCover<string> unused(""); (void)unused; }
  { IntervalCover<shared_ptr<int>> unused(nullptr); (void)unused; }

  auto MkSpan = [](int64 start, int64 end, const string &data) {
    return IntervalCover<string>::Span(start, end, data);
  };

  auto IsSpan = [MkSpan](int64 start, int64 end, const string &data,
			 const IntervalCover<string>::Span &s) 
    -> AssertionResult {
    if (s.start == start &&
	s.end == end &&
	s.data == data)
      return AssertionSuccess();
    else
      return AssertionFailure() << SpanString(MkSpan(start, end, data))
				<< "   but got   "
				<< SpanString(s);
  };

# define OKPOINT(s, e, d, sp) EXPECT_TRUE(IsSpan(s, e, d, sp))

  // Default covers.
  {
    IntervalCover<string> simple("test");

    for (int64 t : vector<int64>{LLONG_MIN, -1LL, 0LL, 1LL, LLONG_MAX}) {
      printf("Look up %lld\n", t);
      OKPOINT(LLONG_MIN, LLONG_MAX, "test", simple.GetPoint(t)) << t;
    }
  }

  // Simple splitting.
  {
    IntervalCover<string> simple("");

    // Split right down the center.
    simple.SplitRight(0LL, "BB");
    OKPOINT(LLONG_MIN, 0LL, "", simple.GetPoint(-1LL));
    OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(0LL));
    OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(1LL));

    // Degenerate split.
    simple.SplitRight(0LL, "BB");
    OKPOINT(LLONG_MIN, 0LL, "", simple.GetPoint(-1LL));
    OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(0LL));
    OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(1LL));

    // Split at 10 with new data.
    //     ------0-----10------
    //       ""     BB    CC
    simple.SplitRight(10LL, "CC");
    OKPOINT(LLONG_MIN, 0LL, "", simple.GetPoint(-1LL));
    OKPOINT(0LL, 10LL, "BB", simple.GetPoint(0LL));
    OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));

    // Split at -10, and left interval to minimum.
    //  --- -10------0-----10------
    //   ZZ      ""     BB    CC
    simple.SplitRight(LLONG_MIN, "ZZ");
    simple.SplitRight(-10LL, "");
    OKPOINT(-10LL, 0LL, "", simple.GetPoint(-10LL));
    OKPOINT(-10LL, 0LL, "", simple.GetPoint(-9LL));
    OKPOINT(0LL, 10LL, "BB", simple.GetPoint(0LL));
    OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
    OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));

    // Split at 5.
    //  --- -10------0---5--10------
    //   ZZ      ""   BB  UU  CC
    simple.SplitRight(5LL, "UU");
    OKPOINT(-10LL, 0LL, "", simple.GetPoint(-10LL));
    OKPOINT(-10LL, 0LL, "", simple.GetPoint(-9LL));
    OKPOINT(0LL, 5LL, "BB", simple.GetPoint(0LL));
    OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
    OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
    OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));

    // Split at -5, merging into BB
    //  --- -10-- -5------5--10------
    //   ZZ     ""    BB   UU  CC
    simple.SplitRight(-5LL, "BB");
    OKPOINT(-10LL, -5LL, "", simple.GetPoint(-10LL));
    OKPOINT(-10LL, -5LL, "", simple.GetPoint(-9LL));
    OKPOINT(-5LL, 5LL, "BB", simple.GetPoint(0LL));
    OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
    OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
    OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));

    // Split on an existing point.
    simple.SplitRight(-5LL, "GG");
    OKPOINT(-10LL, -5LL, "", simple.GetPoint(-10LL));
    OKPOINT(-10LL, -5LL, "", simple.GetPoint(-9LL));
    OKPOINT(-5LL, 5LL, "GG", simple.GetPoint(0LL));
    OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
    OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
    OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));
  }
    
  // Simple overwriting.
  {
    IntervalCover<string> simple("BAD");

    // simple.SetSpan(LLONG_MIN, LLONG_MAX, "OK");
    // OKPOINT(LLONG_MIN, LLONG_MAX, "OK", simple.GetPoint(0LL));
    
    //    simple.SetSpan(LLONG_MIN, 0, "NEG");
    // OKPOINT(LLONG_MIN, 0LL, "NEG", simple.GetPoint(-1LL));
    // OKPOINT(0LL, LLONG_MAX, "OK", simple.GetPoint(0LL));
    simple.SetSpan(0LL, 10LL, "HI");
  }

  printf("IntervalCover tests OK.\n");
  return 0;
}
