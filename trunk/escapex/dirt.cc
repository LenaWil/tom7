
#include "escapex.h"
#include "dirt.h"

typedef ptrlist<SDL_Rect> rlist;

struct dreal : public dirt {
  
  virtual void mirror();
  
  /* PERF could offer mirror_region, which
     allows us to do more local dirtyrect stuff
     by predicting the regions that we will
     need to mirror */
  
  /* enqueue a rectangle to be drawn from the
     mirror. */
  virtual void setdirty(int x, int y, int w, int h);

  /* draw all enqueued dirty rectangles. */
  virtual void clean();

  virtual void destroy() {
    if (surf) SDL_FreeSurface(surf);
    SDL_Rect * tmp;
    while (( tmp = rlist::pop(dirts) )) delete tmp;
  }

  dreal() {
    surf = 0;
    matchscreen();
    dirts = 0;
  }

  void matchscreen() {
    if (!surf || surf->w != screen->w || surf->h != screen->h) {
      if (surf) SDL_FreeSurface(surf);
      surf = sdlutil::makesurface(screen->w, screen->h, false);
    }
  }

private:
  SDL_Surface * surf;

  rlist * dirts;

};

dirt * dirt::create() {
  return new dreal();
}

/* assumes surf is the correct size by invariant */
void dreal::mirror() {
  SDL_BlitSurface(screen, 0, surf, 0);
}

/* XXX one of the following two could be a bit more
   clever. for instance, if there are duplicate or mostly
   overlapping rectangles, we can take their union. If
   there is more dirty area than the screen, we can just
   redraw the whole screen. */
void dreal::setdirty(int x, int y, int w, int h) {
  SDL_Rect * r = (SDL_Rect*)malloc(sizeof (SDL_Rect));
  r->x = x;
  r->y = y;
  r->w = w;
  r->h = h;
  rlist::push(dirts, r);
}

void dreal::clean() {
  SDL_Rect * r;
  while ( (r = rlist::pop(dirts)) ) {
    SDL_BlitSurface(surf, r, screen, r);
    /* debug version */
    //    SDL_FillRect(screen, r, 0x99AA9999);
    free(r);
  }
}
