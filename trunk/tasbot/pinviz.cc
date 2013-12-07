/* This program creates a graphic summarizing
   NES pinball play. It could maybe be generalized
   to other games with static backgrounds?

   Based on scopefun.cc.
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
#include "motifs.h"
#include "../cc-lib/arcfour.h"
#include "util.h"
#include "../cc-lib/textsvg.h"
#include "pngsave.h"
#include "wave.h"
#include "../cc-lib/stb_image.h"

#if MARIONET
#include "SDL.h"
#include "SDL_net.h"
#include "marionet.pb.h"
#include "netutil.h"
using ::google::protobuf::Message;
#endif

enum Room { UNKNOWN, LOW, HIGH, BONUS, };

// Returns true if the pixel is more or less white.
static bool IsWhite(uint32 rgba) {
  uint8 r = 255 & (rgba >> 24);
  uint8 g = 255 & (rgba >> 16);
  uint8 b = 255 & (rgba >> 8);

  return r > 230 && g > 230 && b > 230;
}

// Assumes 256x256 array of RGBA for NES.
static uint32 GetNESPixel(const vector<uint8> &rgba,
			  int x, int y) {
  int idx = 4 * (y * 256 + x);
  return
    ((uint32)rgba[idx + 0] << 24) |
    ((uint32)rgba[idx + 1] << 16) |
    ((uint32)rgba[idx + 2] << 8) |
    ((uint32)rgba[idx + 3] << 0);
}

static Room WhichRoom(const vector<uint8> &rgba) {
  // Note that FCEUX crops off the top 8 pixels of the screen,
  // as well as some of the bottom. Our 256x256 images are
  // raw. So add 8 pixels to the y offsets that were measured
  // from a screenshot.
  //
  // If this is white, then we're either in low or high.
  const int lhx = 85, lhy = 197 + 8;
  // Same but low or bonus.
  const int lbx = 91, lby = 203 + 8;
  // High or bonus.
  const int hbx = 87, hby = 177 + 8;
  
  bool low_or_high = IsWhite(GetNESPixel(rgba, lhx, lhy));
  bool low_or_bonus = IsWhite(GetNESPixel(rgba, lbx, lby));
  bool high_or_bonus = IsWhite(GetNESPixel(rgba, hbx, hby));

  // Look for two confirming signals.
  if (low_or_high && high_or_bonus)
    return HIGH;
  if (low_or_high && low_or_bonus)
    return LOW;
  if (low_or_bonus && high_or_bonus)
    return BONUS;
  
  return UNKNOWN;
}

struct PinViz {
  PinViz(const string &game,
	   const string &moviename,
	   int sf, int mf) : 
    game(game) {

    Emulator::Initialize(game + ".nes");

    // No reason to use caching since we make a single pass.

    movie = SimpleFM2::ReadInputs(moviename);
    
    if (sf < 0) sf = 0;
    if (!mf) mf = movie.size();
    startframe = sf;
    maxframe = mf;

    rgba4x = (uint8 *) malloc(sizeof (uint8) * (width * 4) * (height * 4) * 4);
    CHECK(rgba4x);

    ClearBuffer();
  }

  // Make opaque black.
  void ClearBuffer() {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
	rgba[y * width * 4 + x * 4 + 0] = 0;
	rgba[y * width * 4 + x * 4 + 1] = 0;
	rgba[y * width * 4 + x * 4 + 2] = 0;
	rgba[y * width * 4 + x * 4 + 3] = 0xFF;
      }
    }
  }

  inline void WritePixel(int x, int y,
			 uint8 r, uint8 g, uint8 b, uint8 a) {
    CHECK(x >= 0);
    CHECK(y >= 0);
    CHECK(x < width);
    CHECK(y < height);

    rgba[y * width * 4 + x * 4 + 0] = r;
    rgba[y * width * 4 + x * 4 + 1] = g;
    rgba[y * width * 4 + x * 4 + 2] = b;
    rgba[y * width * 4 + x * 4 + 3] = 0xFF;
  }

  inline void WritePixelTo(int x, int y,
			   uint8 r, uint8 g, uint8 b, uint8 a,
			   uint8 *vec,
			   int ww, int hh) {
    CHECK(x >= 0);
    CHECK(y >= 0);
    CHECK(x < ww);
    CHECK(y < hh);
    
    vec[y * ww * 4 + x * 4 + 0] = r;
    vec[y * ww * 4 + x * 4 + 1] = g;
    vec[y * ww * 4 + x * 4 + 2] = b;
    vec[y * ww * 4 + x * 4 + 3] = 0xFF;
  }

  // Blit(256, 256, 0, 0, 256, 200, 0, 50, screens[i]);
  void Blit(int srcwidth, int srcheight,
	    int rectx, int recty,
	    int rectw, int recth,
	    int dstx, int dsty,
	    const vector<uint8> &srcrgba) {
    for (int y = 0; y < recth; y++) {
      for (int x = 0; x < rectw; x++) {
	// XXX blend alpha!
	uint8 r, g, b, a;
	
	r = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 0];
	g = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 1];
	b = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 2];
	a = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 3];

	// if ((x & 1) != (y & 1)) r ^= 0xFF;

	WritePixel(dstx + x, dsty + y, r, g, b, a);
      }
    }
  }

  void CopyTo4x() {
    const int PXSIZE = 4;
    const int BPP = 4;
    const int width4x = width * PXSIZE;
    // const int height4x = height * PXSIZE;
    // gives offset of start of rgba in the regular size pixel array for
    // the small pixel coordinate (x, y)
#   define SMALLPX(x, y) ((y) * width * BPP + (x) * BPP)
    // gives offset of start of rgba in the big pixel array for
    // the small pixel coordinate (x, y).
#   define BIGPX(x, y) (((y) * PXSIZE) * width4x * BPP + ((x) * PXSIZE) * BPP)
    // offsets from a call to BIGPX.
    // pixel offset (0, 0) is the top left coordinate
    // of the big pixel; (1, 0) is the real pixel to its right, etc.
#   define PXOFFSET(xo, yo) (((xo) * BPP) + ((yo) * width4x * BPP))
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
	// fprintf(stderr, "%d,%d\n", x, y);
	// fflush(stderr);
	uint8 r = rgba[SMALLPX(x, y) + 0];
	uint8 g = rgba[SMALLPX(x, y) + 1];
	uint8 b = rgba[SMALLPX(x, y) + 2];
	uint8 a = rgba[SMALLPX(x, y) + 3];

	for (int yo = 0; yo < PXSIZE; yo++) {
	  for (int xo = 0; xo < PXSIZE; xo++) {
	    rgba4x[BIGPX(x, y) + PXOFFSET(xo, yo) + 0] = r;
	    rgba4x[BIGPX(x, y) + PXOFFSET(xo, yo) + 1] = g;
	    rgba4x[BIGPX(x, y) + PXOFFSET(xo, yo) + 2] = b;
	    rgba4x[BIGPX(x, y) + PXOFFSET(xo, yo) + 3] = a;
	  }
	}

      }
    }
#   undef PXOFFSET
#   undef BIGPX
#   undef SMALLPX
  }


  void Save4x(const string &filename) {
    static const int PXSIZE = 4;
    const int width4x = width * PXSIZE;
    const int height4x = height * PXSIZE;
    CHECK(PngSave::SaveAlpha(filename, width4x, height4x, rgba4x));
  }

  void SaveAV(const string &dir) {
    // Represents the memory BEFORE each frame. Will be one
    // larger than the movie size.
    vector< vector<uint8> > memories;
    // Screen AFTER each frame.
    vector< vector<uint8> > screens;

    // maxframe = 10000;

    for (int i = startframe;
	 i < movie.size() && i < maxframe + 2; i++) {
      vector<uint8> screen;

      if (i % 100 == 0) fprintf(stderr, "%d.\n", i);
      Emulator::StepFull(movie[i]);
      // Image.
      Emulator::GetImage(&screen);
      CHECK(screen.size() == 256 * 256 * 4);
      screens.push_back(screen);
    }

    vector<double> high, low, bonus, unknown;
    high.resize(256 * 256 * 3, 0.0);
    low.resize(256 * 256 * 3, 0.0);
    bonus.resize(256 * 256 * 3, 0.0);
    unknown.resize(256 * 256 * 3, 0.0);
    int num_high = 0, num_low = 0, num_bonus = 0, num_unknown = 0;
    for (int i = 0; i < screens.size(); i++) {
      if (i % 100 == 0) {
	fprintf(stderr, "%d of %d...\n", i, screens.size());
      }
      switch (WhichRoom(screens[i])) {
      case HIGH:
	num_high++;
	Mix(screens[i], &high);
	break;
      case LOW:
	num_low++;
	Mix(screens[i], &low);
	break;
      case BONUS:
	num_bonus++;
	Mix(screens[i], &bonus);
	break;
      case UNKNOWN:
	num_unknown++;
	Mix(screens[i], &unknown);
	break;
      }
    }

    fprintf(stderr,
	    "%d high,   %d low,   %d bonus,   %d unknown.\n",
	    num_high, num_low, num_bonus, num_unknown);

    MapAndWrite("pinball-high.png", high, num_high);
    MapAndWrite("pinball-low.png", low, num_low);
    MapAndWrite("pinball-bonus.png", bonus, num_bonus);
    MapAndWrite("pinball-unknown.png", unknown, num_unknown);

    // Save4x(filename);

    fprintf(stderr, "Done.\n");
  }

  uint8 MapFrac(double r, int num, double darkest, double lightest) {
    const double norm = r / num;
    const double gap = lightest - darkest;

    // double val = 0.20 + (0.80 * norm);
    double val;
    if (norm < 0.20) {
      val = 0.15 + 0.10 * ((norm - darkest) / gap);
    } else {
      val = 0.25 + (0.75 * norm);
    }

    int b = val * 255;
    if (b > 255) return 255;
    if (b < 0) return 0;
    return (uint8) b;
  }

  struct RGBL {
    RGBL(double r, double g, double b) : r(r), g(g), b(b) {
      // Fake luminance. Maybe could just use sum?
      lum = max(r, max(g, b));
    }
    double r;
    double g;
    double b;
    double lum;
  };

  static bool CompareRGBL(const RGBL &a, const RGBL &b) {
    return a.lum < b.lum;
  }

  static bool RGBLEq(const RGBL &a, const RGBL &b) {
    return a.lum == b.lum;
  }

  static int GetIndex(const vector<RGBL> &vec, RGBL rgbl) {
    return std::distance(vec.begin(),
			 std::lower_bound(vec.begin(), vec.end(), rgbl,
					  CompareRGBL));
  }

  static double GetFrac(const vector<RGBL> &vec, RGBL rgbl) {
    return GetIndex(vec, rgbl) / (double)vec.size();
  }

  void MapAndWrite(const string &filename, 
		   const vector<double> &mixed,
		   int num) {
    ClearBuffer();
    CHECK(width * height * 3 == mixed.size());

    double darkest = 1.0, lightest = 0.0;
    vector<RGBL> all_colors;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
	double r = mixed[(y * width + x) * 3 + 0];
	double g = mixed[(y * width + x) * 3 + 1];
	double b = mixed[(y * width + x) * 3 + 2];

	all_colors.push_back(RGBL(r, g, b));

	bool black = (r < (1 / 256.0)) &&
	  (g < (1 / 256.0)) &&
	  (b < (1 / 256.0));

	// Fake luminance...
	double lum = max(r, max(g, b));

	if (!black /* && maxv < 0.20 */) {
	  darkest = min(darkest, lum);
	  lightest = max(lightest, lum);
	}
      }
    }
    
    std::sort(all_colors.begin(), all_colors.end(), &CompareRGBL);
    std::unique(all_colors.begin(), all_colors.end(), &RGBLEq);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
	double r = mixed[(y * width + x) * 3 + 0];
	double g = mixed[(y * width + x) * 3 + 1];
	double b = mixed[(y * width + x) * 3 + 2];

	// Only exactly zero may be mapped as zero.
	bool black = (r < (1 / 256.0)) &&
	  (g < (1 / 256.0)) &&
	  (b < (1 / 256.0));

	uint8 rr, gg, bb;
	if (black) {
	  rr = gg = bb = 0;
	} else {
	  double ord = GetFrac(all_colors, RGBL(r, g, b));
	  // color vector length
	  double len = sqrt(r * r + g * g + b * b);
	  // Normalize
	  double norm_r = r / len;
	  double norm_g = g / len;
	  double norm_b = b / len;
	  // Scale by rank in all colors seen
	  double scale_r = norm_r * ord;
	  double scale_g = norm_g * ord;
	  double scale_b = norm_b * ord;

	  // Now put in 8-bit gamut
	  rr = scale_r * 255.0;
	  gg = scale_g * 255.0;
	  bb = scale_b * 255.0;

	  /*
	  rr = MapFrac(r, num, darkest, lightest);
	  gg = MapFrac(g, num, darkest, lightest);
	  bb = MapFrac(b, num, darkest, lightest);
	  */
	}
	/*
	uint8 rr = (r / num) * 255.0;
	uint8 gg = (g / num) * 255.0;
	uint8 bb = (b / num) * 255.0;
	*/
	WritePixel(x, y, rr, gg, bb, 255);
      }
    }

    CopyTo4x();
    Save4x(filename);
  }

  void Mix(const vector<uint8> &screen,
	   vector<double> *mixed) {
    for (int i = 0; i < screen.size() >> 2; i++) {
      double r = screen[i * 4 + 0];
      double g = screen[i * 4 + 1];
      double b = screen[i * 4 + 2];
      // if (r > 0.0) (*mixed)[i * 3 + 0] += 1.0;
      (*mixed)[i * 3 + 0] += r / 255.0;
      (*mixed)[i * 3 + 1] += g / 255.0;
      (*mixed)[i * 3 + 2] += b / 255.0;
    }
  }

  int startframe, maxframe;

  // Was 220x240.
  // 1/4 HD = 480x270
  static const int width = 256;
  static const int height = 256;
  uint8 rgba[width * height * 4];
  uint8 *rgba4x;

  string game;
  vector<uint8> movie;
};

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  #if MARIONET
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(0) >= 0);
  CHECK(SDLNet_Init() >= 0);
  fprintf(stderr, "SDL initialized OK.\n");
  #endif

  map<string, string> config = Util::ReadFileToMap("config.txt");
  const string game = config["game"];
  string moviename;
  if (argc > 2) {
    fprintf(stderr, "This program takes at most one argument.\n");
    exit(1);
  } else if (argc == 2) {
    moviename = argv[1];
  } else {
    moviename = game + "-playfun-futures-progress.fm2";
    fprintf(stderr, "With no command line argument, assuming movie name\n"
	    "%s\n"
	    " .. from config file.\n", moviename.c_str());
  }
  CHECK(!game.empty());
  CHECK(!moviename.empty());
  
  int startframe = atoi(config["startframe"].c_str());
  int maxframe = atoi(config["maxframe"].c_str());

  PinViz pv(game, moviename, startframe, maxframe);
  string dir = game + "-movie";
  Util::makedir(dir);
  pv.SaveAV(dir);

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();

  #if MARIONET
  SDLNet_Quit();
  SDL_Quit();
  #endif
  return 0;
}
