/* TODO DOCS.
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
#include "weighted-objectives.h"
#include "motifs.h"
#include "../cc-lib/arcfour.h"
#include "util.h"
#include "../cc-lib/textsvg.h"
#include "pngsave.h"
#include "wave.h"

#if MARIONET
#include "SDL.h"
#include "SDL_net.h"
#include "marionet.pb.h"
#include "netutil.h"
using ::google::protobuf::Message;
#endif

struct ScopeFun {
  ScopeFun(const string &game,
	   const string &moviename) : game(game) {

    Emulator::Initialize(game + ".nes");
    objectives = WeightedObjectives::LoadFromFile(game + ".objectives");
    CHECK(objectives);
    fprintf(stderr, "Loaded %d objective functions\n", objectives->Size());

    // No reason to use caching since we make a single pass.

    movie = SimpleFM2::ReadInputs(moviename);

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

  struct MemFact {
    MemFact() : ups(0), downs(0) {}
    // Deciding byte that caused it to go up, down.
    double ups, downs;
    // Was part of an objective that went up, down.
    double allups, alldowns;
    // Weighted number of orderings it's involved in.
    double involved;
  };

  enum Order {
    DOWN, SAME, UP,
  };
  
  struct ObjFact {
    ObjFact() : obj(NULL), weight(0.0), order(SAME) {}
    const vector<int> *obj;
    double weight;
    Order order;
  };

  // Compares two memories and colors based on the objectives
  // that changed during that period. (Rather, it collects the
  // stats that can be used for WriteRAMTo and friends.)
  void MakeMemFacts(const vector<uint8> &mem1,
		    const vector<uint8> &mem2,
		    // Must be the size of memory, zeroed.
		    vector<MemFact> *facts,
		    vector<ObjFact> *objfacts,
		    double *total_weight) {
    *total_weight = 0;

    vector< pair<const vector<int> *, double> > objs = objectives->GetAll();
    objfacts->clear();
    objfacts->resize(objs.size());

    facts->clear();
    facts->resize(2048);

    for (int o = 0; o < objs.size(); o++) {
      const vector<int> &obj = *objs[o].first;
      double weight = objs[o].second;
      *total_weight += weight;
      (*objfacts)[o].obj = &obj;
      (*objfacts)[o].weight = weight;

      Order order = SAME;
      for (int i = 0; i < obj.size(); i++) {
	int p = obj[i];
	if (mem1[p] > mem2[p]) {
	  (*facts)[p].downs += weight;
	  order = DOWN;
	  break;
	}
	if (mem1[p] < mem2[p]) {
	  (*facts)[p].ups += weight;
	  order = UP;
	  break;
	}
      }

      (*objfacts)[o].order = order;
      
      for (int i = 0; i < obj.size(); i++) {
	int p = obj[i];
	// TODO record facts about the objective too.
	switch (order) {
	case UP: (*facts)[p].allups += weight; break;
	case DOWN: (*facts)[p].alldowns += weight; break;
	default:;
	}
	(*facts)[p].involved += weight;
      }
      
    }
  }

  inline void WritePixel(int x, int y,
			 uint8 r, uint8 g, uint8 b, uint8 a) {
    /*
    CHECK(x >= 0);
    CHECK(y >= 0);
    CHECK(x < width);
    CHECK(y < height);
    */
    rgba[y * width * 4 + x * 4 + 0] = r;
    rgba[y * width * 4 + x * 4 + 1] = g;
    rgba[y * width * 4 + x * 4 + 2] = b;
    rgba[y * width * 4 + x * 4 + 3] = 0xFF;
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

  void WriteScoreTo(int xstart, int ystart,
		    const vector<ObjFact> &objfacts) {
    static const int SCOREH = 32;
    static const int SCOREW = 6;

    double total = 0.0;
    double gtotal = 0.0, rtotal = 0.0;
    for (int i = 0; i < objfacts.size(); i++) {
      total += objfacts[i].weight;
      switch (objfacts[i].order) {
      case UP: gtotal += objfacts[i].weight; break;
      case DOWN: rtotal += objfacts[i].weight; break;
      default:;
      }
    }

    int green = floor((gtotal / total) * SCOREH);
    int red = floor((rtotal / total) * SCOREH);
    int blue = SCOREH - red - green;

    for (int y = 0; y < SCOREH; y++) {
      uint8 r, g, b;
      if (y < blue) {
	r = g = 0;
	b = 0x7F;
      } else if (y < blue + red) {
	b = g = 0;
	r = 0xCC;
      } else {
	r = b = 0;
	g = 0xCC;
      }
      for (int x = 0; x < SCOREW; x++) {
	WritePixel(x + xstart, y + ystart, r, g, b, 0xFF);
      }
    }
  }

  void WriteRAMTo(int xstart, int ystart,
		  const vector<uint8> &mem,
		  const vector<MemFact> &memfacts,
		  double total_weight) {
    static const int MEMW = 64;
    static const int MEMH = 32;
    CHECK(MEMW * MEMH == mem.size());

    for (int y = 0; y < MEMH; y++) {
      for (int x = 0; x < MEMW; x++) {
	int idx = y * MEMW + x;
	uint8 byte = mem[idx];

	// Loses some of the low-order bit, which wouldn't be visible
	// anyway, in favor of good color information.
	double value = 0.3 + 0.7 * (byte / 255.0);

	static const double RED_HUE = 0.0;
	static const double GREEN_HUE = 120.0;
	static const double BLUE_HUE = 240.0;

	double hue = 0.0, saturation = 0.0;
	if (memfacts[idx].allups == 0.0 &&
	    memfacts[idx].alldowns == 0.0) {
	  if (memfacts[idx].involved > 0) {
	    hue = BLUE_HUE;
	    saturation = 0.5 + 0.5 * (memfacts[idx].involved / total_weight);
	  } else {
	    hue = 0.0;
	    saturation = 0.0;  // grey
	  }
	} else {
	  if (memfacts[idx].ups > 0.0 &&
	      memfacts[idx].ups > memfacts[idx].downs) {
	    hue = GREEN_HUE;
	    saturation = 1.0;
	  } else if (memfacts[idx].downs > 0.0) {
	    hue = RED_HUE;
	    saturation = 1.0;
	  } else {
	    double sum = memfacts[idx].allups + memfacts[idx].alldowns;
	    hue = (memfacts[idx].allups / sum) * GREEN_HUE +
	      (memfacts[idx].alldowns / sum) * RED_HUE;
	    saturation = 0.5 + 0.5 * (sum / total_weight);
	  }
	}

	uint8 r, g, b;
	HSV(hue, saturation, value, &r, &g, &b);

	WritePixel(x + xstart, y + ystart, r, g, b, 0xFF);
      }
    }
  }

  void Save4x(const string &filename) {
    const int PXSIZE = 4;
    const int BPP = 4;
    const int width4x = width * PXSIZE;
    const int height4x = height * PXSIZE;
    uint8 *rgba4x = (uint8 *)malloc(sizeof (uint8) * width4x * height4x * BPP);
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
    CHECK(PngSave::SaveAlpha(filename, width4x, height4x, rgba4x));
    free(rgba4x);
  }

  void SaveAV(const string &dir) {
    // Represents the memory BEFORE each frame. Will be one
    // larger than the movie size.
    vector< vector<uint8> > memories;
    // Screen AFTER each frame.
    vector< vector<uint8> > screens;
    /*
    static const int STARTFRAMES = 900;
    static const int MAXFRAMES = 1000;
    */
    static const int STARTFRAMES = 280;
    static const int MAXFRAMES = 6000;

    const string wavename = StringPrintf("test%d-%d.wav", STARTFRAMES, MAXFRAMES);
    WaveFile wavefile(wavename);

    for (int i = 0; i < movie.size() && i < MAXFRAMES + 2; i++) {
      vector<uint8> mem, screen;
      Emulator::GetMemory(&mem);
      memories.push_back(mem);
      if (i % 100 == 0) fprintf(stderr, "%d.\n", i);
      Emulator::StepFull(movie[i]);

      // Image.
      Emulator::GetImage(&screen);
      CHECK(screen.size() == 256 * 256 * 4);
      screens.push_back(screen);

      // Sound.
      vector<int16> sound;
      Emulator::GetSound(&sound);
      wavefile.Write(sound);
    }
    {
      vector<uint8> mem_last;
      Emulator::GetMemory(&mem_last);
      memories.push_back(mem_last);
    }

    wavefile.Close();
    fprintf(stderr, "Wrote sound.\n");

    for (int i = STARTFRAMES; i < movie.size() && i < MAXFRAMES; i++) {
      ClearBuffer();

      // Blit(256, 256, 0, 0, 128, 64, 0, 128, screens[i]);
      Blit(256, 256, 0, 0, 256, 256, 0, 0, screens[i]);

      // Previous frame.
      {
	vector<MemFact> facts;
	vector<ObjFact> objfacts;
	double total_weight = 0;
	MakeMemFacts(memories[i], memories[i + 1],
		     &facts, &objfacts, &total_weight);
	WriteRAMTo(257, 0, memories[i + 1], facts, total_weight);
	WriteScoreTo(257 + 65, 0, objfacts);
      }
      
      // Ten frames.
      if (i > 10) {
	vector<MemFact> facts;
	vector<ObjFact> objfacts;

	double total_weight = 0;
	MakeMemFacts(memories[i - 9], memories[i + 1],
		     &facts, &objfacts, &total_weight);
	WriteRAMTo(257, 33, memories[i + 1], facts, total_weight);
	WriteScoreTo(257 + 65, 33, objfacts);
      }

      // One hundred frames.
      if (i > 100) {
	vector<MemFact> facts;
	vector<ObjFact> objfacts;

	double total_weight = 0;
	MakeMemFacts(memories[i - 99], memories[i + 1], 
		     &facts, &objfacts, &total_weight);
	WriteRAMTo(257, 66, memories[i + 1], facts, total_weight);
	WriteScoreTo(257 + 65, 66, objfacts);
      }

      const string filename = StringPrintf("test%d.png", i);
      Save4x(filename);
      fprintf(stderr, "Wrote %s.\n", filename.c_str());
    }

    fprintf(stderr, "Done.\n");
  }

  // Was 220x240.
  // 1/4 HD = 480x270
  static const int width = 480;
  static const int height = 270;
  uint8 rgba[width * height * 4];

  WeightedObjectives *objectives;
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

  ScopeFun pf(game, moviename);
  // XXX in some dir
  string dir = "pngs";
  Util::makedir(dir);
  pf.SaveAV(dir);

  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();

  #if MARIONET
  SDLNet_Quit();
  SDL_Quit();
  #endif
  return 0;
}
