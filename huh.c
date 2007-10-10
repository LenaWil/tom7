#include <stdio.h>

int main (int argc, char ** argv) {
  printf("Hello\n");
  FILE * f = fopen("YEAH", "w");
  fprintf(f, "WOO");
  fclose(f);
}
