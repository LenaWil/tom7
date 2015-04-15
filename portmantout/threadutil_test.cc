#include "threadutil.h"
#include "base/logging.h"

using namespace std;

int main () {

  std::mutex m;
  { 
    MutexLock ml(&m);
    printf("Taking lock OK.\n");
  }
  
  vector<int> nums;
  nums.resize(100);
  ParallelComp(nums.size(), [&nums](int i) {
      nums[i] = i;
    }, 8);

  for (int i = 0; i < nums.size(); i++) {
    CHECK(nums[i] == i);
  }

  printf("Nums ok.");

  return 0;
}
