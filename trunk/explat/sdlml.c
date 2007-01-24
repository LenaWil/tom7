
#include <SDL.h>
// #include <windows.h>

int ml_init() {
  if (SDL_Init (SDL_INIT_VIDEO | 
                SDL_INIT_TIMER | 
		/* for debugging */
		SDL_INIT_NOPARACHUTE |
		SDL_INIT_AUDIO) < 0) {

    printf("Unable to initialize SDL. (%s)\n", SDL_GetError());
    
    return 0;
  } else { 
    SDL_EnableUNICODE(1);
    return 1;
  }
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
  // char msg[512];
  // sprintf(msg, "%p %p %d %d\n", src, dst, x, y);
  // MessageBoxA(0, msg, "do blit:", 0);
  SDL_Rect r;
  r.x = x;
  r.y = y;
  SDL_BlitSurface(src, 0, dst, &r);
  // MessageBoxA(0, "Successful Blit", "uh", 0);
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

SDL_Event * ml_newevent() {
  return (SDL_Event*) malloc (sizeof (SDL_Event));
}

int ml_eventtag(SDL_Event * e) {
  return e->type;
}

int ml_event8_2nd(SDL_Event * e) {
  return (((SDL_KeyboardEvent*)e)->which);
}

int ml_event8_3rd(SDL_Event * e) {
  return (((SDL_KeyboardEvent*)e)->state);
}

int ml_event_keyboard_sym(SDL_KeyboardEvent* e) {
  return e->keysym.sym;
}

int ml_event_keyboard_mod(SDL_KeyboardEvent* e) {
  return e->keysym.mod;
}

int ml_event_keyboard_unicode(SDL_KeyboardEvent* e) {
  return e->keysym.unicode;
}

int ml_event_mmotion_x(SDL_MouseMotionEvent* e) {
  return e->x;
}
int ml_event_mmotion_y(SDL_MouseMotionEvent* e) {
  return e->y;
}
int ml_event_mmotion_xrel(SDL_MouseMotionEvent* e) {
  return e->xrel;
}
int ml_event_mmotion_yrel(SDL_MouseMotionEvent* e) {
  return e->yrel;
}
