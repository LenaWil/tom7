
#ifndef __BLIT_H
#define __BLIT_H

#include "SDL.h"
#include <stdio.h>
#include <stdlib.h>

#define PIXELSIZE 4

// In game pixels.
#define WIDTH 320
#define HEIGHT 200

// TODO: Use good logging package.
#define CHECK(condition) \
  while (!(condition)) {                                    \
    fprintf(stderr, "check failed\n");                      \
    fprintf(stderr, "%d. Check failed: %s\n"                \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

#endif
