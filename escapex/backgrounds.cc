
#include "backgrounds.h"
#include "draw.h"
#include "extent.h"
#include "util.h"
#include "chars.h"

static Uint32 blueish(SDL_Surface * surf) {
  float h = 178.0f + (util::randfrac() * (233.0f - 178.0f));
  float s = .29f + (util::randfrac() * (.84f - .29f));
  float v = .12f + (util::randfrac() * (.50f - .12f));
  float a = .50f + (util::randfrac() * (1.0f - .50f));
  return sdlutil::hsv(surf, h / 360.0f, s, v, a);
}

void backgrounds::gradientblocks(SDL_Surface *& surf) {
  /* PERF could avoid doing this if not resizing, but nobody calls it
     that way (would look weird anyway because gradient would keep
     spazzing out) */
  if (surf) SDL_FreeSurface(surf);

  int w = screen->w;
  int h = screen->h;
  surf = sdlutil::makesurface(w, h, false);
  if (!surf) return;

  // sdlutil::printsurfaceinfo(surf);
  
  SDL_Surface *gradient = sdlutil::makesurface(w, h);
  if (!gradient) return;

  /* why is this necessary? */
  /* I think it is setting the alpha channel,
     because if I just FillRect a small area,
     only that area shows through. */

#if 0
  sdlutil::clearsurface(surf,
			SDL_MapRGBA(surf->format,
				    0xFF, 0xFF, 0xFF, 0xFF));
#endif

  for(int y = 0; y < 1 + h / (TILEW >> 1); y ++)
    for(int x = 0; x < 1 + w / (TILEH >> 1); x ++) {
      drawing::drawtile(x * (TILEH >> 1), y * (TILEW >> 1),
			((x + y) & 1) ? T_BLUE : T_GREY,
			1, surf);
    }


  /* gradient. we pick a bunch of random points and then
     interpolate between them. */

  sdlutil::clearsurface(gradient, 
			SDL_MapRGBA(gradient->format, 
				    0xFF, 0xFF, 0xFF, 0xFF));

  int x = 0;
  Uint32 last = blueish(gradient);
  Uint32 next = blueish(gradient);
  int count = 1;
  int num = 0;
  while (x < w) {
    SDL_Rect rect;
    rect.y = 0;
    rect.h = h;
    rect.w = 1;
    rect.x = x;

    Uint32 clr;

    if (num >= count) {
      /* pick a new nextination color */
      clr = sdlutil::mixfrac(last, next, 0.5f);
      last = next;
      next = blueish(gradient);
      count = 2 + (int)(util::randfrac() * 28.0f);
      num = 0;
    } else {
      num ++;
      clr = sdlutil::mixfrac(last, next, num/(float)count);
    }

    SDL_FillRect(gradient, &rect, clr);
    x ++;
  }

  SDL_BlitSurface(gradient, 0, surf, 0);
  SDL_FreeSurface(gradient);
}
