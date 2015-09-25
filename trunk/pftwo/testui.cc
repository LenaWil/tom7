#include <vector>
#include <string>
#include <set>
#include <memory>

#include <stdio.h>
#include <stdlib.h>

#if 0
#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#endif

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"
#include "../cc-lib/sdl/sdlutil.h"
#include "../cc-lib/util.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/textsvg.h"
#include "../cc-lib/stb_image.h"

#include "../cc-lib/base/logging.h"

#include "SDL.h"

#define WIDTH 1920
#define HEIGHT 1080
SDL_Surface *screen = 0;

// assumes RGBA, surfaces exactly the same size, etc.
static void CopyRGBA(const vector<uint8> &rgba, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, &rgba[0], surface->w * surface->h * 4);
}

#if 0
struct Graphic {
  // From a PNG file.
  explicit Graphic(const string &filename) {
    int bpp;
    uint8 *stb_rgba = stbi_load(filename.c_str(), 
				&width, &height, &bpp, 4);
    CHECK(stb_rgba);
    for (int i = 0; i < width * height * 4; i++) {
      rgba.push_back(stb_rgba[i]);
      //       if (bpp == 3 && (i % 3 == 2)) {
      // rgba.push_back(0xFF);
      //}
    }
    stbi_image_free(stb_rgba);
    fprintf(stderr, "%s is %dx%d @%dbpp = %d bytes\n",
	    filename.c_str(), width, height, bpp,
	    rgba.size());

    surf = sdlutil::makesurface(width, height, true);
    CHECK(surf);
    CopyRGBA(rgba, surf);
  }

  // to screen
  void Blit(int x, int y) {
    sdlutil::blitall(surf, screen, x, y);
  }

  int width, height;
  vector<uint8> rgba;
  SDL_Surface *surf;
};
#endif

struct InputStream {
  InputStream(const string &seed, int length) {
    v.reserve(length);
    ArcFour rc(seed);
    rc.Discard(1024);

    uint8 b = 0;

    for (int i = 0; i < length; i++) {
      if (rc.Byte() < 210) {
        // Keep b the same as last round.
      } else {
        switch (rc.Byte() % 20) {
        case 0:
        default:
          b = INPUT_R;
          break;
        case 1:
          b = INPUT_U;
          break;
        case 2:
          b = INPUT_D;
          break;
        case 3:
        case 11:
          b = INPUT_R | INPUT_A;
          break;
        case 4:
        case 12:
          b = INPUT_R | INPUT_B;
          break;
        case 5:
        case 13:
          b = INPUT_R | INPUT_B | INPUT_A;
          break;
        case 6:
        case 14:
          b = INPUT_A;
          break;
        case 7:
        case 15:
          b = INPUT_B;
          break;
        case 8:
          b = 0;
          break;
        case 9:
          b = rc.Byte() & (~(INPUT_T | INPUT_S));
          break;
        case 10:
          b = rc.Byte();
        }
      }
      v.push_back(b);
    }
  }

  vector<uint8> v;

  decltype(v.begin()) begin() { return v.begin(); }
  decltype(v.end()) end() { return v.end(); }
};


struct Testui {
  std::unique_ptr<Emulator> emu;
  
  Testui() : rc("testui") {
    screen = sdlutil::makescreen(WIDTH, HEIGHT);
    CHECK(screen);

    string game = "mario";
    CHECK(!game.empty());
    emu.reset(Emulator::Create(game + ".nes"));
    CHECK(emu.get());
  }

  void Play() {
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    int frame = 0;

    for (uint8 input : InputStream("poo", 9999)) {
      frame++;
      // Ignore events for now
      SDL_Event event;
      SDL_PollEvent(&event);
      switch (event.type) {
      case SDL_QUIT:
	return;
      }
      
      SDL_Delay(1000.0 / 60.0);
      
      emu->StepFull(input);

      vector<uint8> image = emu->GetImage();
      CopyRGBA(image, surf);

      sdlutil::clearsurface(screen, 0xFFFFFFFF);

      // Draw pixels to screen...
      sdlutil::blitall(surf, screen, 0, 0);
      
      SDL_Flip(screen);
    }
  }
  
  ArcFour rc;
};

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");

  {
    Testui testui;
    testui.Play();
  }

  SDL_Quit();
  return 0;
}
