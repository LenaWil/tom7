
#include <SDL.h>

int ml_test() {
  if (SDL_Init (SDL_INIT_VIDEO | 
                SDL_INIT_TIMER | 
		/* for debugging */
		SDL_INIT_NOPARACHUTE |
		SDL_INIT_AUDIO) < 0) {

    printf("Unable to initialize SDL. (%s)\n", SDL_GetError());
    
    return 0;
  }
  else return 1;
}

SDL_Surface * ml_makescreen(int w, int h) {
  /* Can't use HWSURFACE here, because not handling this SDL_BlitSurface
     case mentioned in the documentation:

     "If either of the surfaces were in video memory, and the blit returns -2, 
     the video memory was lost, so it should be reloaded with artwork 
     and re-blitted." 

     Plus, on Windows, the only time you get HWSURFACE is with FULLSCREEN.

     -- Adam
  */

  /* SDL_ANYFORMAT	
     "Normally, if a video surface of the requested bits-per-pixel (bpp) 
     is not available, SDL will emulate one with a shadow surface. 
     Passing SDL_ANYFORMAT prevents this and causes SDL to use the 
     video surface, regardless of its pixel depth."

     Probably should not pass this.

     -- Adam
  */


  /* SDL_DOUBLEBUF only valid with SDL_HWSURFACE! */
  SDL_Surface * ret = SDL_SetVideoMode(w, h, 32,
				       SDL_SWSURFACE |
				       SDL_RESIZABLE);
  return ret;
}

void ml_blitall(SDL_Surface * src, SDL_Surface * dst, int x, int y) {
  SDL_Rect r;
  r.x = x;
  r.y = y;
  SDL_BlitSurface(src, 0, dst, &r);
}

int ml_surfacewidth(SDL_Surface * src) {
  return src->w;
}

int ml_surfaceheight(SDL_Surface * src) {
  return src->h;
}

void ml_clearsurface(SDL_Surface * s, Uint32 color) {
  SDL_FillRect(s, 0, color);
}
