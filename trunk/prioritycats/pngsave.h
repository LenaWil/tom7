
#ifndef __PNGSAVE_H
#define __PNGSAVE_H

#include <string>
#include <SDL.h>

using namespace std;

struct pngsave {

  /* save PNG to the specified filename. (24 bit without alpha, 32 bit
     with). returns zero on failure, nonzero on success. */
  static int save(const string & fname, SDL_Surface *, bool alpha = false);

};

#endif
