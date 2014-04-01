/* Hack for SIGBOVIK.
*/

#include <vector>
#include <string>
#include <set>

#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "tasbot.h"

#include "fceu/driver.h"
#include "fceu/drivers/common/args.h"
#include "fceu/state.h"
#include "basis-util.h"
#include "emulator.h"
#include "fceu/fceu.h"
#include "fceu/types.h"
#include "simplefm2.h"
#include "../cc-lib/arcfour.h"
#include "sdlutil-lite.h"
#include "util.h"
#include "../cc-lib/textsvg.h"

#include "SDL.h"
#include "SDL_net.h"
#include "marionet.pb.h"
#include "netutil.h"
using ::google::protobuf::Message;

#define WIDTH 256
#define HEIGHT 256
SDL_Surface *screen = 0;

// XXX learnfun should write this to a file called game.base64.
#define BASE64 "base64:jjYwGG411HcjG/j9UOVM3Q=="

// assumes RGBA, surfaces exactly the same size, etc.
static void CopyRGBA(const vector<uint8> &rgba, SDL_Surface *surface) {
  int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, &rgba[0], surface->w * surface->h * 4);
}

struct Sigbovik {
  Sigbovik() : log(NULL), rc("sigbovik") {
    map<string, string> config = Util::ReadFileToMap("sigbovik-config.txt");
    if (config.empty()) {
      fprintf(stderr, "You need a file called config.txt; please "
	      "take a look at the README.\n");
      abort();
    }

    game = config["game"];
    // const string moviename = config["movie"];
    CHECK(!game.empty());
    // CHECK(!moviename.empty());

    screen = sdlutil::makescreen(WIDTH, HEIGHT);
    CHECK(screen);

    Emulator::Initialize(game + ".nes");

    // XXX configure this via config.txt
    // For 64-bit machines with loads of ram
    // Emulator::ResetCache(100000, 10000);
    // For modest systems
    Emulator::ResetCache(1, 1);

    #if 0
    solution = SimpleFM2::ReadInputs(moviename);

    size_t start = 0;
    bool saw_input = false;
    while (start < solution.size()) {
      Commit(solution[start], "warmup");
      watermark++;
      saw_input = saw_input || solution[start] != 0;
      if (start > FASTFORWARD && saw_input) break;
      start++;
    }
    #endif
  }

  void Play() {
    // XXX inputs from web thing
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    for (;;) {
      // Ignore events for now
      SDL_Event event;
      SDL_PollEvent(&event);
      switch (event.type) {
      case SDL_QUIT:
	return;
      }

      Emulator::Step(rc.Byte());

      vector<uint8> image;
      Emulator::GetImage(&image);
      CopyRGBA(image, surf);
      // Draw pixels to screen...
      sdlutil::blitall(surf, screen, 0, 0);
      SDL_Flip(screen);
    }
  }

  // Used to ffwd to gameplay.
  vector<uint8> solution;

  FILE *log;
  ArcFour rc;
  string game;
};

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0);
  CHECK(SDLNet_Init() >= 0);
  fprintf(stderr, "SDL initialized OK.\n");

  Sigbovik sigbovik;

  sigbovik.Play();

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();

  SDLNet_Quit();
  SDL_Quit();
  return 0;
}
