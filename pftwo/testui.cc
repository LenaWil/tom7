#include <vector>
#include <string>
#include <set>
#include <memory>

#include <cstdio>
#include <cstdlib>

#include "pftwo.h"

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"
#include "../cc-lib/sdl/sdlutil.h"
#include "../cc-lib/util.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/textsvg.h"
#include "../cc-lib/stb_image.h"

#include "motifs.h"
#include "weighted-objectives.h"

#include "SDL.h"

#define WIDTH 1920
#define HEIGHT 1080
SDL_Surface *screen = 0;

// assumes ARGB, surfaces exactly the same size, etc.
static void CopyARGB(const vector<uint8> &argb, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, &argb[0], surface->w * surface->h * 4);
}

static inline constexpr uint8 Mix4(uint8 v1, uint8 v2, uint8 v3, uint8 v4) {
  return (uint8)(((uint32)v1 + (uint32)v2 + (uint32)v3 + (uint32)v4) >> 2);
}

static void HalveARGB(const vector<uint8> &argb, int width, int height, SDL_Surface *surface) {
  // PERF
  const int halfwidth = width >> 1;
  const int halfheight = height >> 1;
  vector<uint8> argb_half;
  argb_half.resize(halfwidth * halfheight * 4);
  for (int y = 0; y < halfheight; y++) {
    for (int x = 0; x < halfwidth; x++) {
      #define PIXEL(i) \
	argb_half[(y * halfwidth + x) * 4 + (i)] =	\
	  Mix4(argb[(y * 2 * width + x * 2) * 4 + (i)], \
	       argb[(y * 2 * width + x * 2 + 1) * 4 + (i)], \
	       argb[((y * 2 + 1) * width + x * 2) * 4 + (i)],	\
	       argb[((y * 2 + 1) * width + x * 2 + 1) * 4 + (i)])
      PIXEL(0);
      PIXEL(1);
      PIXEL(2);
      PIXEL(3);
    }
  }
  CopyARGB(argb_half, surface);
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
    CopyARGB(rgba, surf);
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
  std::unique_ptr<WeightedObjectives> objectives;
  std::unique_ptr<Motifs> motifs;

  Testui() : rc("testui") {
    map<string, string> config = Util::ReadFileToMap("config.txt");
    if (config.empty()) {
      fprintf(stderr, "Missing config.txt.\n");
      abort();
    }

    string game = config["game"];
    const string moviename = config["movie"];
    CHECK(!game.empty());
    CHECK(!moviename.empty());

    // XXX: On 4 Oct 2015 these were hand-written objectives.
    objectives.reset(WeightedObjectives::LoadFromFile(game + ".objectives"));
    CHECK(objectives.get());
    fprintf(stderr, "Loaded %d objective functions\n", (int)objectives->Size());

    motifs.reset(Motifs::LoadFromFile(game + ".motifs"));
    CHECK(motifs);

    screen = sdlutil::makescreen(WIDTH, HEIGHT);
    CHECK(screen);

    emu.reset(Emulator::Create(game + ".nes"));
    CHECK(emu.get());
  }

  void Play() {
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    SDL_Surface *surfhalf = sdlutil::makesurface(128, 128, true);
    int frame = 0;

    for (uint8 input : InputStream("poo", 9999)) {
      frame++;
      // Ignore events for now
      SDL_Event event;
      SDL_PollEvent(&event);
      switch (event.type) {
      case SDL_QUIT:
	return;
      case SDL_KEYDOWN:
	switch (event.key.keysym.sym) {
	case SDLK_ESCAPE:
	  return;
	default:;
	}
	break;
      default:;
      }
      
      // SDL_Delay(1000.0 / 60.0);
      
      emu->StepFull(input);

      if (frame % 1 == 0) {
	vector<uint8> image = emu->GetImageARGB();
	CopyARGB(image, surf);
	HalveARGB(image, 256, 256, surfhalf);
	
	sdlutil::clearsurface(screen, 0x00000000);

	// Draw pixels to screen...
	sdlutil::blitall(surf, screen, 0, 0);
	sdlutil::blitall(surfhalf, screen, 260, 0);
	
	SDL_Flip(screen);
      }
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
