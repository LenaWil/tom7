
#include "smlversion.h"

int counter = 0;

SDL_Surface *screen;

static SDL_Surface *MakeScreen(int w, int h) {
  SDL_Surface * ret = SDL_SetVideoMode(w, h, 32,
                                       SDL_SWSURFACE);
  return ret;
}

static void ClearSurface(SDL_Surface *s, Uint32 color) {
  SDL_FillRect(s, 0, color);
}

typedef unsigned char uint8;

void InitGame() {
  screen = MakeScreen(WIDTH * PIXELSIZE, HEIGHT * PIXELSIZE);
  ClearSurface(screen, 1234567);
  SDL_Flip(screen);
}

void FillScreenFrom(Uint32 *inpixels) {
  SDL_Surface *surf = screen;
  // printf("RGB %d %d %d\n", R, G, B);
  CHECK(surf->format->BytesPerPixel == 4);
  // CHECK(inpixels[0] == 0xFFAAAAAA);

  // PERF Worth experimenting with different ways of pipelining this.
  for (int y = 0; y < HEIGHT; y++) {
    for (int x = 0; x < WIDTH; x++) {
      Uint32 color = inpixels[y * WIDTH + x];
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
