
// Just for LoadLibrary. Maybe could use an extern decl.
#if 0
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#include <cstdint>

#include "SDL.h"
#include "sdl/sdlutil.h"
#include "math.h"

using namespace std;

using uint32 = uint32_t;
using uint64 = uint64_t;
using uint16 = uint16_t;
using uint8 = uint8_t;
using int64 = int64_t;
using int32 = int32_t;

// We use these interchangeably; ensure that they are consistent.
// The S* and U* versions come from SDL, the simple ones from base.h.
// (TODO: Is there a way to check that the types are literally
// the same?)
static_assert(sizeof(Sint64) == sizeof(int64), "int 64");
static_assert(sizeof(Uint64) == sizeof(uint64), "uint 64");
static_assert(sizeof(Sint32) == sizeof(int32), "int 32");
static_assert(sizeof(Uint32) == sizeof(uint32), "uint 32");
static_assert(sizeof(Uint16) == sizeof(uint16), "uint 16");
static_assert(sizeof(Uint8) == sizeof(uint8), "uint 8");

#define PI 3.14159265358979323846264338327950288419716939937510
#define TWOPI (2.0 * PI) // 6.28318530718


#define STARTW 1920
#define STARTH 1080

// TODO: Make into little library. Make constexpr mixcolor that's
// correct for the platform.
static constexpr uint32 RGBA(uint8 r, uint8 g, uint8 b, uint8 a) {
  return (a << 24) |
    (r << 16) |
    (g << 8) |
    b;
}
static constexpr uint32 RED = RGBA(0xFF, 0x0, 0x0, 0xFF);
static constexpr uint32 BLACK = RGBA(0x0, 0x0, 0x0, 0xFF);
static constexpr uint32 WHITE = RGBA(0xFF, 0xFF, 0xFF, 0xFF);
static constexpr uint32 GREEN = RGBA(0x0, 0xFF, 0x0, 0xFF);
static constexpr uint32 BLUE = RGBA(0x0, 0x0, 0xFF, 0xFF);
static constexpr uint32 BACKGROUND = RGBA(0x00, 0x20, 0x00, 0xFF);

// XXX whither?
static SDL_Surface *screen;

int main(int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  SDL_EnableUNICODE(1);
  screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, BACKGROUND); 
  SDL_Flip(screen);

  auto Draw = []() {
    sdlutil::clearsurface(screen, BACKGROUND);


    sdlutil::fillrect(screen, BLUE, 12, 12, 100, 100);
  };

  while(1) {
    SDL_Event e;
    /* event loop */
    while (SDL_PollEvent(&e)) {
      switch(e.type) {
      case SDL_QUIT:
	return 0;

      case SDL_KEYDOWN: {
	int key = e.key.keysym.sym;
	switch(key) {
	case SDLK_SPACE: {
	  break;
	}
	case SDLK_r: {
	  break;
	}
	case SDLK_ESCAPE:
	  return 0;
	default:;
	}
      }
	
      default:;
      }
    }

    Draw();
    SDL_Flip(screen);

    SDL_Delay(0);
  }

  return 0;
}
