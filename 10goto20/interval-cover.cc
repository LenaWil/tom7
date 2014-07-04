
#include "interval-cover.h"

template<>
void IntervalCover<string>::DebugPrint() const {
  printf("------\n");
  for (const pair<const int64, string> &p : spans) {
    printf("%lld: %s\n", p.first, p.second.c_str());
  }
  printf("------\n");
}

template<>
void IntervalCover<int>::DebugPrint() const {
  printf("------\n");
  for (const pair<const int64, int> &p : spans) {
    printf("%lld: %d\n", p.first, p.second);
  }
  printf("------\n");
}
