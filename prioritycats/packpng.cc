
using namespace std;

#include "sdlutil.h"

#include "util.h"
#include "extent.h"
#include "pngsave.h"

#include <set>
#include <map>
#include <iostream>
#include <fstream>

/* XXX necessary? */
SDL_Surface * screen;
string self;

#define BACKCOLOR 0xAA338833

#define WIDTH 25
#define HEIGHT 25

typedef unsigned long long uint64;

uint64 HashSurface(SDL_Surface *pic) {
  uint64 h = 0x0DDBALL;
  for (int y = 0; y < pic->h; y++) {
    for (int x = 0; x < pic->w; x++) {
      h *= 0x1234567LL;
      h ^= 3377117733LL;
      h %= 0xFF33AA3174LL;
      h += 0x371957611LL;
      Uint32 p = sdlutil::getpixel(pic, x, y);
      h += p << 11;
      // h = (h >> 11) | (h << (64 - 11));
    }
  }
  return h;
}

int main (int argc, char ** argv) {

  /* change to location of binary, so that we can find the
     images needed. */
  if (argc > 0) {
    string wd = util::pathof(argv[0]);
    util::changedir(wd);

#   if WIN32
    /* on win32, the ".exe" may or may not
       be present. Also, the file may have
       been invoked in any CaSe. */
    self = util::lcase(util::fileof(argv[0]));
    self = util::ensureext(self, ".exe");
#   else
    self = util::fileof(argv[0]);
#   endif

  }

  if (argc != 3) {
    printf("\n"
	   "Usage: splitpng startidx input\n");
    printf("Splits the file called input.png (do not supply an extension)\n"
	   "into a bunch of %dx%d ones. Also writes on\n"
	   "stdout the necessary definitions for tiles.js, assuming that\n"
	   "the first unused tile index is the first commandline parameter.\n"
	   "Output files go into the tiles subdirectory.\n",
	   WIDTH, HEIGHT);
    return 1;
  }

  /* we don't really need any SDL modules */
  if (SDL_Init (SDL_INIT_NOPARACHUTE) < 0) {
    printf("Unable to initialize SDL. (%s)\n", SDL_GetError());
    return 1;
  }

  map<uint64, int> seen;

  // First load everything in tiles.js, so that if we use a tile that
  // already exists (like if we drew over a background) then we
  // don't need to emit it at all. We don't actually parse the json,
  // but recognize lines that start with " { id: "; they look like
  // this:
  //  { id: 23, isbg: false, frames: ['house18', 1] },
  // If we miss this optimization, nothing bad happens; it's just
  // wasteful. So I only recognize single-frame images.
  string tilesjs = readfile("tiles.js");
  while (!tilesjs.empty()) {
    string line = util::getline(tilesjs);
    if (util::startswith(line, " { id: ")) {
      // in scope..
      int id = atoi(line.substr(7, string::npos).c_str());
      if (!id) continue;

      // First frame:
      size_t fr = line.find("frames: ['");
      fr += sizeof("frames: ['") - 1;
      if (fr == string::npos) continue;
      size_t frend = line.find("', 1]", fr);
      if (frend == string::npos) continue;
      string frame = line.substr(fr, frend - fr);
      SDL_Surface *pic = IMG_Load(((string)"tiles/" + frame + ".png").c_str());
      if (!pic) continue;
      uint64 h = HashSurface(pic);
      fprintf(stderr, "Old: %d [%s] = %llx\n", id, frame.c_str(), h);
      seen[h] = id;
      SDL_FreeSurface(pic);
    }
  }

  string startidxs = argv[1];
  int startidx = atoi(startidxs.c_str());
  string basename = argv[2];
  string input = basename + ".png";
  SDL_Surface * pic = IMG_Load(input.c_str());


  if (!pic) {
    printf("Can't read %s\n", input.c_str());
    exit(-1);
  }

  // Don't blend, copy alpha channel.
  SDL_SetAlpha(pic, 0, 255);

  // We just keep reusing this one.
  SDL_Surface * one = sdlutil::makesurface(WIDTH, HEIGHT);
  sdlutil::clearsurface(one, BACKCOLOR);

  if (!one) abort();

  printf("Input pic is %d by %d.\n", pic->w, pic->h);

  
  string macro = (string)"{ w: " + itos(pic->w / WIDTH) + 
    (string)", h: " + itos(pic->h / HEIGHT) +
    (string)", t: [";

  bool any = false;
  int idx = 1;
  // Screen coords.
  for (int y = 0; y < pic->h; y += HEIGHT) {
    for (int x = 0; x < pic->w; x += WIDTH) {
      SDL_Rect rd, wr;
      rd.x = x;
      rd.y = y;
      rd.w = WIDTH;
      rd.h = HEIGHT;
      wr.x = 0;
      wr.y = 0;
      SDL_BlitSurface(pic, &rd, one, &wr);

      if (any) macro += ", ";
      uint64 h = HashSurface(one);
      if (seen.find(h) == seen.end()) {
	char outname[512];
	sprintf(outname, "tiles/%s%d.png", basename.c_str(), idx);

	if (!pngsave::save(outname, one, true)) {
	  printf("Couldn't write output PNG.\n");
	  return -1;
	}
	
	int thisidx = startidx + idx - 1;
	printf(" { id: %d, isbg: true, frames: ['%s%d', 1] },\n", 
	       thisidx,
	       basename.c_str(), idx);
	macro += itos(thisidx);
	seen[h] = thisidx;
	idx++;
	any = true;
      } else {
	printf(" // duplicate: %d,%d: %llx = %d\n", x, y, h, seen[h]);
	macro += itos(seen[h]);
	any = true;
      }
    }
  }

  macro += " ]}";
  printf("\nMacro:\n%s\n", macro.c_str());

  fflush(stdout);
  SDL_FreeSurface(pic);
  SDL_FreeSurface(one);

  printf("Done!\n");

  return 0;
}
