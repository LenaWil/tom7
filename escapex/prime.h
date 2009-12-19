
#ifndef __PRIME_H
#define __PRIME_H

struct prime {
  /* return a random integer relatively prime to x (> 0) */
  static int relativeto(int x);

  /* table of the first nprimes primes */
  static int nprimes;
  static int primetable[];

};


#endif
