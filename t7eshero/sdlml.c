
#include <SDL.h>
// #include <windows.h>

/* by default, use display format. but
   when in console mode (for instance)
   there is no display!! */
#ifndef USE_DISPLAY_FORMAT
# define USE_DISPLAY_FORMAT 1
#endif

/* XXX It seems that byte order doesn't affect the
   ordering of the colors within a Uint32. */
#if 0 /* SDL_BYTEORDER == SDL_BIG_ENDIAN */
  const Uint32 rmask = 0xff000000;
  const Uint32 gmask = 0x00ff0000;
  const Uint32 bmask = 0x0000ff00;
  const Uint32 amask = 0x000000ff;
  const Uint32 rshift = 24;
  const Uint32 gshift = 16;
  const Uint32 bshift = 8;
  const Uint32 ashift = 0;
#else
  const Uint32 rmask = 0x000000ff;
  const Uint32 gmask = 0x0000ff00;
  const Uint32 bmask = 0x00ff0000;
  const Uint32 amask = 0xff000000;
  const Uint32 ashift = 24;
  const Uint32 bshift = 16;
  const Uint32 gshift = 8;
  const Uint32 rshift = 0;
#endif

int ml_init() {
  if (SDL_Init (SDL_INIT_VIDEO | 
                SDL_INIT_TIMER | 
		SDL_INIT_JOYSTICK |
		SDL_INIT_AUDIO |
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

void slock(SDL_Surface *surf) {
  if(SDL_MUSTLOCK(surf))
    SDL_LockSurface(surf);
}

void sulock(SDL_Surface *surf) {
  if (SDL_MUSTLOCK(surf))
    SDL_UnlockSurface(surf);
}

/* out has room for 512 chars */
void ml_joystickname (int i, char * out) {
  const char * p = SDL_JoystickName(i);
  if (p) {
    strncpy(out, p, 512);
  }
}

void ml_setjoystate(int i) {
  SDL_JoystickEventState(i?SDL_ENABLE:SDL_IGNORE);
}

/* try to make a hardware surface, and, failing that,
   make a software surface */
SDL_Surface * makesurface(int w, int h, int alpha) {

  /* PERF need to investigate relative performance 
     of sw/hw surfaces */
  SDL_Surface * ss = 0;
#if 0
    SDL_CreateRGBSurface(SDL_HWSURFACE |
			 (alpha?SDL_SRCALPHA:0),
			 w, h, 32, 
			 rmask, gmask, bmask,
			 amask);
#endif

  if (!ss) ss = SDL_CreateRGBSurface(SDL_SWSURFACE |
				     (alpha?SDL_SRCALPHA:0),
				     w, h, 32,
				     rmask, gmask, bmask,
				     amask);

  if (ss && !alpha) SDL_SetAlpha(ss, 0, 255);

  /* then convert to the display format. */
# if USE_DISPLAY_FORMAT
  if (ss) {
    SDL_Surface * rr;
    if (alpha) rr = SDL_DisplayFormatAlpha(ss);
    else rr = SDL_DisplayFormat(ss);
    SDL_FreeSurface(ss);
    return rr;
  } else return 0;
# else
  return ss;
# endif
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

void ml_blit(SDL_Surface * src, int srcx, int srcy, int srcw, int srch, 
	     SDL_Surface * dst, int dstx, int dsty) {
  SDL_Rect sr;
  SDL_Rect dr;
  sr.x = srcx;
  sr.y = srcy;
  sr.w = srcw;
  sr.w = srcw;
  dr.x = dstx;
  dr.y = dsty;
  SDL_BlitSurface(src, &sr, dst, &dr);
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

/* XXX should lock before calling (for certain modes)... */
void ml_drawpixel(SDL_Surface *surf, int x, int y,
		  int R, int G, int B) {
  Uint32 color = SDL_MapRGB(surf->format, R, G, B);
  switch (surf->format->BytesPerPixel) {
    case 1: // Assuming 8-bpp
      {
        Uint8 *bufp;
        bufp = (Uint8 *)surf->pixels + y*surf->pitch + x;
        *bufp = color;
      }
      break;
    case 2: // Probably 15-bpp or 16-bpp
      {
        Uint16 *bufp;
        bufp = (Uint16 *)surf->pixels + y*surf->pitch/2 + x;
        *bufp = color;
      }
      break;
    case 3: // Slow 24-bpp mode, usually not used
      {
        Uint8 *bufp;
        bufp = (Uint8 *)surf->pixels + y*surf->pitch + x * 3;
        if(SDL_BYTEORDER == SDL_LIL_ENDIAN) {
	    bufp[0] = color;
	    bufp[1] = color >> 8;
	    bufp[2] = color >> 16;
	  } else {
	    bufp[2] = color;
	    bufp[1] = color >> 8;
	    bufp[0] = color >> 16;
	  }
      }
      break;
    case 4: // Probably 32-bpp
      {
        Uint32 *bufp;
        bufp = (Uint32 *)surf->pixels + y*surf->pitch/4 + x;
        *bufp = color;
      }
      break;
    }
}


SDL_Surface * ml_alphadim(SDL_Surface * src) {
  /* must be 32 bpp */
  if (src->format->BytesPerPixel != 4) return 0;

  int ww = src->w, hh = src->h;
  
  SDL_Surface * ret = makesurface(ww, hh, 1);

  if (!ret) return 0;

  slock(ret);
  slock(src);

  int y, x;

  for(y = 0; y < hh; y ++)
    for(x = 0; x < ww; x ++) {
      Uint32 color = *((Uint32 *)src->pixels + y*src->pitch/4 + x);
      
      /* divide alpha channel by 2 */
      /* XXX this seems to be wrong on powerpc (dims some other channel
	 instead). but if the masks are right, how could this go wrong? */
      color =
	(color & (rmask | gmask | bmask)) |
	(((color & amask) >> 1) & amask);
  
      *((Uint32 *)ret->pixels + y*ret->pitch/4 + x) = color;

    }

  sulock(src);
  sulock(ret);

  return ret;
}
