
// TODO: This test probably isn't stressing enough; there was
// a serious crasher in SplitRight (it didn't check whether next
// was .end() before trying to merge with it) that wasn't caught
// by the tests here. Consider more aggressive stress tests.

#include "interval-cover.h"

#include <stdlib.h>
#include <set>
#include <vector>
#include <string>
#include <memory>
#include <iostream>

#include "arcfour.h"
#include "base.h"
#include "gtest/gtest.h"
#include "base/stringprintf.h"

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

string SpanString(const IntervalCover<string>::Span &span) {
  string st = (span.start == LLONG_MIN) ? "MIN" : 
    StringPrintf("%lld", span.start);
  string en = (span.end == LLONG_MAX) ? "MAX" : 
    StringPrintf("%lld", span.end);
  return StringPrintf("[%s, \"%s\", %s)",
		      st.c_str(), span.data.c_str(), en.c_str());
}


IntervalCover<string>::Span MkSpan(int64 start, int64 end, const string &data) {
  return IntervalCover<string>::Span(start, end, data);
}

AssertionResult IsSpan(int64 start, int64 end, const string &data,
		       const IntervalCover<string>::Span &s) {
  if (s.start == start &&
      s.end == end &&
      s.data == data)
    return AssertionSuccess();
  else
    return AssertionFailure() << SpanString(MkSpan(start, end, data))
			      << "   but got   "
			      << SpanString(s);
}

TEST(IC, Trivial) {
  // Check that it compiles with some basic types.
  { IntervalCover<int> unused(0); (void)unused; }
  { IntervalCover<double> unused(1.0); (void)unused; }
  { IntervalCover<string> unused(""); (void)unused; }
  { IntervalCover<shared_ptr<int>> unused(nullptr); (void)unused; }
}

TEST(IC, Easy) {
  // Easy-peasy.
  IntervalCover<string> easy("everything");
  EXPECT_EQ(LLONG_MIN, easy.First());
  EXPECT_FALSE(easy.IsAfterLast(LLONG_MIN));
  EXPECT_FALSE(easy.IsAfterLast(0LL));
  EXPECT_TRUE(easy.IsAfterLast(LLONG_MAX));
}

#define OKPOINT(s, e, d, sp) EXPECT_TRUE(IsSpan(s, e, d, sp))

TEST(IC, Copying) {
  IntervalCover<string> easy_a("everything");
  {
    IntervalCover<string> easy_b = easy_a;

    OKPOINT(LLONG_MIN, LLONG_MAX, "everything", easy_a.GetPoint(0LL));
    OKPOINT(LLONG_MIN, LLONG_MAX, "everything", easy_b.GetPoint(0LL));

    easy_a.SetSpan(-10LL, 10LL, "NO");
    OKPOINT(-10LL, 10LL, "NO", easy_a.GetPoint(0LL));
    OKPOINT(LLONG_MIN, LLONG_MAX, "everything", easy_b.GetPoint(0LL));
  }
  
  OKPOINT(-10LL, 10LL, "NO", easy_a.GetPoint(0LL));
}

TEST(IC, DefaultCovers) {
  IntervalCover<string> simple("test");
  simple.CheckInvariants();
  for (int64 t : vector<int64>{ LLONG_MIN, -1LL, 0LL, 1LL, LLONG_MAX }) {
    OKPOINT(LLONG_MIN, LLONG_MAX, "test", simple.GetPoint(t)) << t;
  }
}

TEST(IC, SimpleSplitting) {
  IntervalCover<string> simple("");
  simple.CheckInvariants();

  // Split right down the center.
  simple.SplitRight(0LL, "BB");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, 0LL, "", simple.GetPoint(-1LL));
  OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(0LL));
  OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(1LL));

  // Degenerate split.
  simple.SplitRight(0LL, "BB");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, 0LL, "", simple.GetPoint(-1LL));
  OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(0LL));
  OKPOINT(0LL, LLONG_MAX, "BB", simple.GetPoint(1LL));

  // Split at 10 with new data.
  //     ------0-----10------
  //       ""     BB    CC
  simple.SplitRight(10LL, "CC");
  simple.CheckInvariants();
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
  simple.CheckInvariants();
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
  simple.CheckInvariants();
  OKPOINT(-10LL, -5LL, "", simple.GetPoint(-10LL));
  OKPOINT(-10LL, -5LL, "", simple.GetPoint(-9LL));
  OKPOINT(-5LL, 5LL, "BB", simple.GetPoint(0LL));
  OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
  OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
  OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));

  // Split on an existing point, replacing BB with GG.
  //  --- -10-- -5------5--10------
  //   ZZ     ""    GG   UU  CC
  simple.SplitRight(-5LL, "GG");
  simple.CheckInvariants();
  OKPOINT(-10LL, -5LL, "", simple.GetPoint(-10LL));
  OKPOINT(-10LL, -5LL, "", simple.GetPoint(-9LL));
  OKPOINT(-5LL, 5LL, "GG", simple.GetPoint(0LL));
  OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
  OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
  OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));

  // Split such that GG has to merge with the interval to its left.
  //  --- -10-----------5--10------
  //   ZZ     ""         UU  CC
  simple.SplitRight(-5LL, "");
  simple.CheckInvariants();
  OKPOINT(-10LL, 5LL, "", simple.GetPoint(0LL));
  OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
  OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
  OKPOINT(LLONG_MIN, -10LL, "ZZ", simple.GetPoint(-20LL));

  // Split to make a sandwich of UUs.
  //  ------ -15-- -10-----------5--10------
  //   ZZ       UU      ""        UU  CC
  simple.SplitRight(-15LL, "UU");
  simple.CheckInvariants();
  OKPOINT(-10LL, 5LL, "", simple.GetPoint(0LL));
  OKPOINT(5LL, 10LL, "UU", simple.GetPoint(6LL));
  OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
  OKPOINT(LLONG_MIN, -15LL, "ZZ", simple.GetPoint(-20LL));
  OKPOINT(-15LL, -10LL, "UU", simple.GetPoint(-14LL));

  // Now test merging on both sides.
  //  ------ -15--------------------10------
  //   ZZ       UU                    CC
  simple.SplitRight(-10LL, "UU");
  simple.CheckInvariants();
  OKPOINT(-15LL, 10LL, "UU", simple.GetPoint(0LL));
  OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));
  OKPOINT(LLONG_MIN, -15LL, "ZZ", simple.GetPoint(-20LL));

  // Merge off to infinity on the left.
  // Now test merging on both sides.
  //  ------------------------------10------
  //   ZZ                             CC
  simple.SplitRight(-15LL, "ZZ");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, 10LL, "ZZ", simple.GetPoint(0LL));
  OKPOINT(10LL, LLONG_MAX, "CC", simple.GetPoint(10LL));

  // And into one interval again.
  //  --------------------------------------
  //   CC                               
  simple.SplitRight(LLONG_MIN, "CC");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, LLONG_MAX, "CC", simple.GetPoint(0LL));
}

TEST(IC, SplitStress) {
  IntervalCover<string> cover("X");
  for (int i = 0; i < 500; i++) {
    vector<int64> pts = { -100LL, 10LL, 30LL, 0LL, 6LL, 7LL, LLONG_MIN,
			  LLONG_MAX - 10LL, 999LL, -1LL, 50LL, 60LL, 51LL, };
    Shuffle(&pts);
    int z = 0;
    for (int64 pt : pts) {
      z++;
      string s = StringPrintf("%lld", z);
      cover.SplitRight(pt, s);
      cover.CheckInvariants();
      EXPECT_EQ(s, cover.GetPoint(pt).data);
      EXPECT_LE(cover.GetPoint(pt).start, pt);
      EXPECT_LT(pt, cover.GetPoint(pt).end);
    }

    // Now merge back together in random order.
    Shuffle(&pts);
    for (int64 pt : pts) {
      cover.SplitRight(pt, "BACK");
      cover.CheckInvariants();
      EXPECT_EQ("BACK", cover.GetPoint(pt).data);
    }

    OKPOINT(LLONG_MIN, LLONG_MAX, "BACK", cover.GetPoint(0LL));
  }
}

TEST(IC, SetSpan) {
  IntervalCover<string> simple("BAD");
  simple.CheckInvariants();

  simple.SetSpan(LLONG_MIN, LLONG_MAX, "OK");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, LLONG_MAX, "OK", simple.GetPoint(0LL));

  simple.SetSpan(LLONG_MIN, 0LL, "NEG");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, 0LL, "NEG", simple.GetPoint(-1LL));
  OKPOINT(0LL, LLONG_MAX, "OK", simple.GetPoint(0LL));

  simple.SetSpan(-10LL, 10LL, "MIDDLE");
  simple.CheckInvariants();

  simple.SetSpan(10LL, 20LL, "NEXT");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, -10LL, "NEG", simple.GetPoint(-100LL));
  OKPOINT(-10LL, 10LL, "MIDDLE", simple.GetPoint(0LL));
  OKPOINT(-10LL, 10LL, "MIDDLE", simple.GetPoint(-1LL));
  OKPOINT(-10LL, 10LL, "MIDDLE", simple.GetPoint(1LL));
  OKPOINT(10LL, 20LL, "NEXT", simple.GetPoint(11LL));
  OKPOINT(20LL, LLONG_MAX, "OK", simple.GetPoint(100LL));


  simple.SetSpan(LLONG_MIN, LLONG_MAX, "BYE");
  simple.CheckInvariants();
  OKPOINT(LLONG_MIN, LLONG_MAX, "BYE", simple.GetPoint(0LL));
}

int main(int argc, char **argv) {
  InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
