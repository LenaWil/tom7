
#include "smlversion.h"

int counter = 0;

SDL_Surface *screen;

static SDL_Surface *MakeScreen(int w, int h) {

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
                                       SDL_SWSURFACE /* | SDL_RESIZABLE */);
  return ret;
}

static void ClearSurface(SDL_Surface *s, Uint32 color) {
  SDL_FillRect(s, 0, color);
}

typedef unsigned char uint8;
static uint8 ii = 0, jj = 0;
static uint8 ss[256];

void InitGame() {
  screen = MakeScreen(WIDTH * PIXELSIZE, HEIGHT * PIXELSIZE);
  ClearSurface(screen, 1234567);
  SDL_Flip(screen);

  static const uint8 kk[256] = "--------------------a-3--------------------e-------------------------------e-e----------------------------------f----------------------------------------------z-----------------------------------------------------------------------------------------000----";
  for (int i = 0; i < 256; i++) {
    ss[i] = i;
  }
  uint8 i = 0, j = 0;
  for (int n = 256; n--;) {
    j += ss[i] + kk[i];
    uint8 t = ss[i];
    ss[i] = ss[j];
    ss[j] = t;
    i++;
  }
}

static uint8 Byte() {
  ii++;
  jj += ss[ii];
  uint8 ti = ss[ii];
  uint8 tj = ss[jj];
  ss[ii] = tj;
  ss[jj] = ti;

  return ss[(ti + tj) & 255];
}

// XXX locking?
void FillScreen2x() {
  SDL_Surface *surf = screen;
  static Sint64 r = 0x50, g = 0x80, b = 0xFE, a = 0xFF, f = 0xFFFFFF;
  // printf("RGB %d %d %d\n", R, G, B);
  CHECK(surf->format->BytesPerPixel == 4);

  for (int y = 0; y < HEIGHT; y++) {
    for (int x = 0; x < WIDTH; x++) {
#if 0
      f = (f * 67) & 0xFFFFFFFF;
      f = f * 156;
      f += x;
      f = f & 0xFFFFFF;

      r *= 25;
      r += (x + counter / 32);
      g++;
      g *= (y + counter);
      b *= 31337;
      b += f;
      f = r ^ g;
#endif
      uint8 r = Byte(), g = Byte(), b = Byte();

      // PERF?
      Uint32 color = SDL_MapRGB(surf->format, r, g, b);
      Uint32 *pixels = (Uint32 *)surf->pixels;

      // pixel offset of top-left corner of megapixel
      int o = (y * PIXELSIZE * (WIDTH * PIXELSIZE) + x * PIXELSIZE);
      pixels[o] = color;
      #if PIXELSIZE > 1
      pixels[o + 1] = color;
      pixels[o + (WIDTH * PIXELSIZE)] = color;
      pixels[o + (WIDTH * PIXELSIZE) + 1] = color;
      #endif
      #if PIXELSIZE > 2
      // right column
      pixels[o + 2] = color;
      pixels[o + (WIDTH * PIXELSIZE) + 2] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 2 + 2] = color;
      // bottom row
      pixels[o + (WIDTH * PIXELSIZE) * 2] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 2 + 1] = color;
      #endif
      #if PIXELSIZE > 3
      // right column
      pixels[o + 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) + 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 2 + 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 3 + 3] = color;
      // bottom row
      pixels[o + (WIDTH * PIXELSIZE) * 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 3 + 1] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 3 + 2] = color;
      #endif
      #if PIXELSIZE > 4
      # error Only pixel size 1, 2, 3, 4 are supported.
      #endif
    }
  }

  SDL_Flip(screen);
}
