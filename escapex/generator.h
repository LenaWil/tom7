
#ifndef __GENERATOR_H
#define __GENERATOR_H

/* uses a mixed linear congruential generator
   to generate random-like permutations of 0...size-1 */

/* the generator is   Xn =   a * X(n-1) + c   mod size

   currently we always use some prime that does not divide size
   (so they are relatively prime), and a = 1. To get generators 
   (with period size) for a > 1, we must satisfy the following
   conditions, which are not trivial:

    a - 1 is a multiple of p, for every prime p dividing m
    a - 1 is a multiple of 4, if m is a multiple of 4
*/
struct generator {
  /* size must be >= 1 */
  generator(unsigned int size);
  /* always generate 0..size-1 in order;
     pointer is ignored */
  generator(unsigned int size, void *);

  /* use as
     for (generator g(x); g.anyleft(); g.next ()) {
      ... g.item () ...
     }
  */
  
  bool anyleft ();
  unsigned int item();
  void next ();


  private:

  unsigned int size;
  unsigned int a;
  unsigned int c;
  unsigned int x;
  
  int left;

};


#endif
