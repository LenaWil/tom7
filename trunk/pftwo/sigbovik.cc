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
#include "../cc-lib/stb_image.h"

#include "SDL.h"
#include "SDL_net.h"
#include "marionet.pb.h"
#include "netutil.h"
using ::google::protobuf::Message;

#define BOVIKWIDTH 186
#define HEADHEIGHT 70
#define FEETY 163
#define DIGITWIDTH 10

#define WIDTH (256 + BOVIKWIDTH)
#define HEIGHT 256
SDL_Surface *screen = 0;

// XXX learnfun should write this to a file called game.base64.
#define BASE64 "base64:jjYwGG411HcjG/j9UOVM3Q=="

// assumes RGBA, surfaces exactly the same size, etc.
static void CopyRGBA(const vector<uint8> &rgba, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, &rgba[0], surface->w * surface->h * 4);
}

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

struct Sigbovik {
  vector<Graphic> heads, feet, bodies, digits;

  Sigbovik() : log(NULL), rc("sigbovik") {
    screen = sdlutil::makescreen(WIDTH, HEIGHT);
    CHECK(screen);

    map<string, string> config = Util::ReadFileToMap("sigbovik-config.txt");
    if (config.empty()) {
      fprintf(stderr, "You need a file called config.txt; please "
	      "take a look at the README.\n");
      abort();
    }

    for (int i = 0; i < 8; i++) {
      string filename = StringPrintf("head%d.png", i);
      heads.push_back(Graphic(filename));
      string feetname = StringPrintf("feet%d.png", i);
      feet.push_back(Graphic(feetname));
      string bodyname = StringPrintf("body%d.png", i);
      bodies.push_back(Graphic(bodyname));
    }

    for (int i = 0; i < 10; i++) {
      string name = StringPrintf("digit%d.png", i);
      digits.push_back(Graphic(name));
    }

    game = config["game"];
    // const string moviename = config["movie"];
    CHECK(!game.empty());
    // CHECK(!moviename.empty());

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
    uint8 headbyte = 0, feetbyte = 171, bodybyte = 41,
      mem1 = 0, mem2 = 0;
    int frame = 0;
    for (;;) {
      frame++;
      // Ignore events for now
      SDL_Event event;
      SDL_PollEvent(&event);
      switch (event.type) {
      case SDL_QUIT:
	return;
      }
      
      SDL_Delay(1000.0 / 60.0);
      
      string votefile = Util::ReadFile("current_vote");
      int current_vote = atoi(votefile.c_str());
      uint8 input = 0;
      if (current_vote > 0) {
	input = 1 << (current_vote - 1);
      }
      printf("Current input: %s\n", SimpleFM2::InputToString(input).c_str());
      Emulator::Step(input);

      vector<uint8> image;
      Emulator::GetImage(&image);
      CopyRGBA(image, surf);

      sdlutil::clearsurface(screen, 0xFFFFFFFF);

      // Draw pixels to screen...
      sdlutil::blitall(surf, screen, BOVIKWIDTH, 0);

      // and sigbovik person
      // XXX get from RAM
      // XXX change update rate sometimes
      if (frame % 20 == 0) {

	vector<uint8> mem;
	Emulator::GetMemory(&mem);
	headbyte = mem[0xdc];
	bodybyte = mem[0x34];
	feetbyte = mem[0x308] + mem[0x1f6] + mem[0x1d4];

	mem1 = mem[0xef];
	mem2 = mem[0xf0];
      }

      Graphic &head = heads[headbyte & 7];
      Graphic &foot = feet[feetbyte & 7];
      Graphic &body = bodies[bodybyte & 7];
      head.Blit(0, 0);
      body.Blit(0, 0);
      foot.Blit(0, FEETY);

      DrawNumber(mem1, 0, 0);
      DrawNumber(mem2, 60, 0);
      
      SDL_Flip(screen);
    }
  }

  void DrawNumber(uint8 n, int x, int y) {
    int d1 = n / 100;
    int d2 = (n % 100) / 10;
    int d3 = n % 10;
    digits[d1].Blit(x, y);
    digits[d2].Blit(x + DIGITWIDTH, y);
    digits[d3].Blit(x + DIGITWIDTH + DIGITWIDTH, y);
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
