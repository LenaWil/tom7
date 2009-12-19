
#include "generator.h"
#include "util.h"
#include "prime.h"

generator::generator(unsigned int s) : size(s), a(1) {
  /* generate a random prime c that does
     not divide size. */
  c = prime::relativeto(s);

  /* pick any random starting point */
  x = ((unsigned)util::random()) % size;

  /* period is equal to size */
  left = (int)size;

  /*
    printf("generator: start %d, c = %d, size = %d\n",
    x, c, size); */
}

generator::generator(unsigned int s, void * ignored) 
  : size(s), a(1), c(1), x(0) {
  left = (int)size;
}

void generator::next () {
  x = (a * x + c) % size;
  left --;
  if (left < 0) left = 0;
  /* printf("next item is %d\n", x); */
}

unsigned int generator::item () {
  return x;
}

bool generator::anyleft () {
  return !!left;
}
