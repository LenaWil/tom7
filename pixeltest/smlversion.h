
#ifndef __SMLVERSION_H
#define __SMLVERSION_H

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
    printf(stderr, "check failed\n"); \
    fprintf(stderr, "%s:%d. Check failed: "                 \
            __FILE__, __LINE__, #condition                  \
            );                                              \
    abort();                                                \
  }

#endif
