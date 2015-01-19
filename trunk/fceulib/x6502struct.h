#ifndef _X6502STRUCTH
#define _X6502STRUCTH

struct X6502 {
  /* Temporary cycle counter */
  int32 tcount;

  /* I'll change this to uint32 later...
     I'll need to AND PC after increments to 0xFFFF
     when I do, though.  Perhaps an IPC() macro? */

  uint16 PC;
  uint8 A, X, Y, S, P, mooPI;
  uint8 jammed;

  int32 count;
  /* Simulated IRQ pin held low(or is it high?).
     And other junk hooked on for speed reasons.*/
  uint32 IRQlow;
  /* Data bus "cache" for reads from certain areas */
  uint8 DB;

  /* Pre-exec'ing for debug breakpoints. */
  int preexec;

};

#endif
