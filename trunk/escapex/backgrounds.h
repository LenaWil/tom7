#ifndef __BACKGROUNDS_H
#define __BACKGROUNDS_H

#include "escapex.h"
#include "draw.h"
#include "sdlutil.h"
#include "drawable.h"

struct backgrounds {

  /* Creates a checkerboard pattern of blocks with
     a random vertical gradient atop it. Modifies
     surf so that it points to an surface with the
     same size as the screen, if it doesn't already. */
  static void gradientblocks(SDL_Surface *& surf,
			     int tile_white,
			     int tile_black,
			     float gradient_hue);

  static const float blueish;
  static const float purpleish;

 private:
  backgrounds();
};

#endif
