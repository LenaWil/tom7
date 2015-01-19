// Generates a mean C++ source file that contains 2^32 newlines
// and then uses the __LINE__ macro.

#include <stdlib.h>
#include <stdio.h>
#include <cstdint>

int main () {
  FILE *f = fopen("awesome.cc", "wb");
  for (int64_t i = 0; i < 4294967296LL; i++) {
    fputc('\n', f);
  }
  fprintf(f, "%s", R"!(
#include <iostream>
int main() {
  std::cout << __LINE__ << std::endl;
  return 0;
}
)!");
  fclose(f);
  return 0;
}
