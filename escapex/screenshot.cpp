#include "escapex.h"
#include "level.h"
#include "sdlutil.h"

#include "util.h"
#include "font.h"
#include "extent.h"
#include "draw.h"
#include "pngsave.h"
#include "animation.h"

SDL_Surface * screen;
string self;
int network;

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
    fprintf(stderr,
	    "Usage: screenshot /path/to/level.esx /path/to/output.png\n");
    fprintf(stderr, 
	    "(relative paths will be interpreted from the location of the\n"
	    " screenshot binary.)\n");
    return 1;
  }

  /* we don't really need any SDL modules */
  if (SDL_Init (SDL_INIT_NOPARACHUTE) < 0) {

    fprintf(stderr, "Unable to initialize SDL. (%s)\n", SDL_GetError());

    return 1;
  }
  
  int x = 0;
  if (!(drawing::loadimages() && 
	(x = 1) &&
	animation::ainit_fast())) {
    fprintf(stderr, "%d Failed to load graphics.\n", x);
    SDL_Quit();
    return 1;
  }

  /* actually do screenshot stuff */

  string inlev = argv[1];
  string outpng = argv[2];

  int zf = 0;

  drawing d;
  d.lev = level::fromstring(readfile(inlev));
  if (!d.lev) {
    fprintf(stderr, "Can't open %s\n", inlev.c_str());
    SDL_Quit ();
    return -2;
  }

  /* now zoom out until the level fits in the
     target size */
  while (((d.lev->w * (TILEW >> zf)) > 300 ||
	  (d.lev->h * (TILEH >> zf)) > 300) &&
	 zf < (DRAW_NSIZES - 1)) {
    zf ++;
  }

  d.margin = 1;
  d.width = (d.lev->w * (TILEW >> zf)) + (2 * d.margin);
  d.height = (d.lev->h * (TILEH >> zf)) + (2 * d.margin);
  d.zoomfactor = zf;

  SDL_Surface * shot = sdlutil::makesurface(d.width, d.height);

  if (!shot) {
    fprintf(stderr, "Can't make surface\n");
    SDL_Quit ();
    return -4;
  }

  d.drawlev(0, shot);

  pngsave::save(outpng, shot);


  /* clean up and exit */

  SDL_FreeSurface(shot);

  drawing::destroyimages();

  return 0;
}
