
#include <stdio.h>

int main(int argc, char **argv) {
  printf("WRONG.\n");
  (void)fopen("wrongone", "w");
  return -1;
}
