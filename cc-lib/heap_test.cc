
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <cstdint>

#include "heap.h"

using namespace std;

using uint64 = uint64_t;

struct TestValue : public Heapable {
  TestValue(uint64 i) : i(i) {}
  uint64 i;
};

static uint64 CrapHash(int a) {
  uint64 ret = ~a;
  ret *= 31337;
  ret ^= 0xDEADBEEF;
  ret = (ret >> 17) | (ret << (64 - 17));
  ret -= 911911911911;
  ret *= 65537;
  ret ^= 0xCAFEBABE;
  return ret;
}

int main () {
  static constexpr int kNumValues = 1000;
  
  Heap<uint64, TestValue> heap;
  
  vector<TestValue> values;
  for (int i = 0; i < kNumValues; i++) {
    values.push_back(TestValue(CrapHash(i)));
  }

  for (int i = 0; i < values.size(); i++) {
    heap.Insert(values[i].i, &values[i]);
  }

  TestValue *last = heap.PopMinimumValue();
  while (!heap.Empty()) {
    TestValue *now = heap.PopMinimumValue();
    fprintf(stderr, "%llu %llu\n", last->i, now->i);
    if (now->i < last->i) {
      printf("FAIL: %llu %llu\n", last->i, now->i);
      return -1;
    }
    last = now;
  }

  for (int i = 0; i < values.size(); i++) {
    if (values[i].location != -1) {
      printf("FAIL! %d still in heap at %d\n", i, values[i].location);
      return -1;
    }
  }
  
  for (int i = 0; i < values.size() / 2; i++) {
    heap.Insert(values[i].i, &values[i]);
  }

  heap.Clear();
  if (!heap.Empty()) {
    printf("FAIL: Heap not empty after clear?\n");
    return -1;
  }

  for (int i = 0; i < values.size() / 2; i++) {
    if (values[i].location != -1) {
      printf("FAIL (B)! %d still in heap at %d\n", i, values[i].location);
      return -1;
    }
  }
  
  printf("OK\n");
  return 0;
}
