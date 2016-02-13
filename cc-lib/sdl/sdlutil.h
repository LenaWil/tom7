
// XXX "lite" copy that doesn't need SDL_Image
//////////////////////////////////////////////////////////////////////
// Where did imgload go? I stopped using SDL_Image in favor of
// stb_image, which doesn't need to link stuff like libpng, zlib,
// libjpeg, etc. etc. etc. which is a nightmare. The only use was
// in this library. It is easy to replicate the functionality of
// imgload using stb_image; and I should probably do that in this
// package since both are part of cc-lib.
//////////////////////////////////////////////////////////////////////

#ifndef __SDLUTIL_H
#define __SDLUTIL_H

#include "SDL.h"

struct sdlutil {
  static SDL_Surface *makescreen(int w, int h);
  static void slock(SDL_Surface *surf);
  static void sulock(SDL_Surface *surf);

  /* eat and ignore all the events in the queue for a few ticks */
  static void eatevents(int ticks, Uint32 mask = 0xFFFFFFFF);

  /* for direct pixel access: lock first, unlock after */
  static void drawpixel(SDL_Surface *surf, int x, int y,
                        Uint8 R, Uint8 G, Uint8 B);
  static void drawclippixel(SDL_Surface *surf, int x, int y,
			    Uint8 R, Uint8 G, Uint8 B);
  static Uint32 getpixel(SDL_Surface *, int x, int y);
  static void   setpixel(SDL_Surface *, int x, int y,
                         Uint32 color);

  // Load supported files using stb_image.
  static SDL_Surface *LoadImage(const char *filename);

  static SDL_Surface *duplicate(SDL_Surface *surf);

  // Unchecked--don't draw outside the surface!
  static void drawline(SDL_Surface *, int x1, int y1, int x2, int y2,
                       Uint8 R, Uint8 G, Uint8 B);

  static void drawclipline(SDL_Surface *, int x1, int y1, int x2, int y2,
			   Uint8 R, Uint8 G, Uint8 B);

  // Efficiently clip the line segment (x0,y0)-(x1,y1) to the rectangle
  // (cx0,cy0)-(cx1,cy1). Modifies the endpoints to place them on the
  // rectangle if they exceed its bounds. Returns false if the segment
  // is completely outside the rectangle, in which case the endpoints
  // can take on any values.
  static bool clipsegment(float cx0, float cy0, float cx1, float cy1,
			  float &x0, float &y0, float &x1, float &y1);
  
  // With clipping.
  static void drawbox(SDL_Surface *, int x1, int y1, int w, int h,
		      Uint8 r, Uint8 g, Uint8 b);
  
  static void clearsurface(SDL_Surface *, Uint32);

  /* make a n pixel border around a surface. */
  static void outline(SDL_Surface *, int n, int r, int g, int b, int a);

  /* Blit the entire source surface to the destination at the given
     position. */
  static void blitall(SDL_Surface *src, SDL_Surface *dst, int x, int y);

  /* Just like SDL_Fillrect, but no need to create SDL_Rects */
  static void fillrect(SDL_Surface *, Uint32 color,
                       int x, int y, int w, int h);

  /* create a rectangle of the specified size, filled with a color
     at a certain alpha value. This can then be blit to the screen. */
  static SDL_Surface *makealpharect(int w, int h, int r,
				    int g, int b, int a);

  /* make an alpha rectangle with a vertical gradient between the two
     specified colors.  bias should be between 0 and 1; a higher bias
     means the gradient will have more of the bottom color.
  */
  static SDL_Surface *makealpharectgrad(int w, int h,
					int r1, int b1, int g1, int a1,
					int r2, int b2, int g2, int a2,
					float bias = 0.5f);

  static SDL_Surface *makesurface(int w, int h, bool alpha = true);

  /* make a new surface with the same contents as the old, or 'color' where
     undefined */
  static SDL_Surface *resize_canvas(SDL_Surface *s, int w, int h, Uint32 color);

  /* print out flags and maybe other things */
  static void printsurfaceinfo(SDL_Surface *surf);

  /* shrink a 32bpp surface to 50% of its original size,
     returning the new surface. */
  static SDL_Surface *shrink50(SDL_Surface *src);

  /* Grow to 2x its original size, returning a new surface. */
  static SDL_Surface *grow2x(SDL_Surface *src);

  /* create a mipmap array (of nmips successively half-sized images)
     in the array surfs. The first entry of surfs should be filled
     with a surface, so for nmips==1 this does nothing. */
  static bool make_mipmaps(SDL_Surface **surfs, int nmips);

  /* divide alpha channel by 2 */
  static SDL_Surface *alphadim(SDL_Surface *src);

  /* flip a surface horizontally */
  static SDL_Surface *fliphoriz(SDL_Surface *src);

  /* mix two 32bit colors, doing the right thing for alpha */
  static Uint32 mix2(Uint32, Uint32);

  /* mix four 32bit colors, byte-order agnostic */
  static Uint32 mix4(Uint32, Uint32, Uint32, Uint32);

  /* frac should be between 0 and 1, and we get frac of the first
     color and 1-frac of the second */
  static Uint32 mixfrac(Uint32, Uint32, float frac);

  static const Uint32 rmask, gmask, bmask, amask;

  /* convert from hue-saturation-value-alpha space to RGBA (compatible
     with the supplied surface) */
  static Uint32 hsv(SDL_Surface *surf, float h, float s, float v, float a);

};

#endif
