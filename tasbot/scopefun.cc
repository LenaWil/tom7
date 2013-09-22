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
#include "../cc-lib/stb_image.h"

#if MARIONET
#include "SDL.h"
#include "SDL_net.h"
#include "marionet.pb.h"
#include "netutil.h"
using ::google::protobuf::Message;
#endif

struct Graphic {
  // From a PNG file.
  explicit Graphic(const string &filename) {
    int bpp;
    uint8 *stb_rgba = stbi_load(filename.c_str(), 
				&width, &height, &bpp, 4);
    CHECK(stb_rgba);
    for (int i = 0; i < width * height * bpp; i++) {
      rgba.push_back(stb_rgba[i]);
    }
    stbi_image_free(stb_rgba);
    fprintf(stderr, "%s is %dx%d @%dbpp.\n",
	    filename.c_str(), width, height, bpp);
  }

  int width, height;
  vector<uint8> rgba;
};

struct ScopeFun {
  ScopeFun(const string &game,
	   const string &moviename,
	   int sf, int mf, bool so, bool fo) : 
    controller("controller.png"),
    controllerdown("controllerdown.png"),
    game(game),
    soundonly(so),
    fatobjectivelines(fo) {

    Emulator::Initialize(game + ".nes");
    objectives = WeightedObjectives::LoadFromFile(game + ".objectives");
    CHECK(objectives);
    fprintf(stderr, "Loaded %d objective functions\n", (int)objectives->Size());

    // No reason to use caching since we make a single pass.

    movie = SimpleFM2::ReadInputs(moviename);
    
    if (sf < 0) sf = 0;
    if (!mf) mf = movie.size();
    startframe = sf;
    maxframe = mf;

    rgba4x = (uint8 *) malloc(sizeof (uint8) * (width * 4) * (height * 4) * 4);
    CHECK(rgba4x);

    ClearBuffer();

    if (soundonly) {
      fprintf(stderr, "sound-only mode.\n");
    }
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

  // XXX This function is used inconsistently; either remove
  // the alpha param or use it...
  inline void WritePixel(int x, int y,
			 uint8 r, uint8 g, uint8 b, uint8 a) {
    DCHECK(x >= 0);
    DCHECK(y >= 0);
    DCHECK(x < width);
    DCHECK(y < height);

    rgba[y * width * 4 + x * 4 + 0] = r;
    rgba[y * width * 4 + x * 4 + 1] = g;
    rgba[y * width * 4 + x * 4 + 2] = b;
    rgba[y * width * 4 + x * 4 + 3] = 0xFF;
  }

  inline uint32 GetPixel(int x, int y) {
    DCHECK(x >= 0);
    DCHECK(y >= 0);
    DCHECK(x < width);
    DCHECK(y < height);

    uint32 r = rgba[y * width * 4 + x * 4 + 0];
    uint32 g = rgba[y * width * 4 + x * 4 + 1];
    uint32 b = rgba[y * width * 4 + x * 4 + 2];
    uint32 a = rgba[y * width * 4 + x * 4 + 3];
    return (r << 24) | (g << 16) | (b << 8) | a;
  }

  static inline void WritePixelTo(int x, int y,
				  uint8 r, uint8 g, uint8 b,
				  uint8 *vec,
				  int ww, int hh) {
    DCHECK(x >= 0);
    DCHECK(y >= 0);
    DCHECK(x < ww);
    DCHECK(y < hh);
    
    vec[y * ww * 4 + x * 4 + 0] = r;
    vec[y * ww * 4 + x * 4 + 1] = g;
    vec[y * ww * 4 + x * 4 + 2] = b;
    vec[y * ww * 4 + x * 4 + 3] = 0xFF;
  }

  // Blends alpha, assuming dest alpha is 0xFF.
  static inline void WritePixelAlphaTo(int x, int y,
				       uint8 r, uint8 g, uint8 b, uint8 a,
				       uint8 *vec,
				       int ww, int hh) {
    DCHECK(x >= 0);
    DCHECK(y >= 0);
    DCHECK(x < ww);
    DCHECK(y < hh);

    uint32 oldr = vec[y * ww * 4 + x * 4 + 0];
    uint32 oldg = vec[y * ww * 4 + x * 4 + 1];
    uint32 oldb = vec[y * ww * 4 + x * 4 + 2];
    uint32 oma = 0xFF - a;

    // Each value was multiplied by 256 (max alpha),
    // so divide to put in range again. Since we are
    // blending with (1-a) and all integer, there's 
    // no possibility of overflow.
    uint32 mixr = ((uint32)r * a + oldr * oma) >> 8;
    uint32 mixg = ((uint32)g * a + oldg * oma) >> 8;
    uint32 mixb = ((uint32)b * a + oldb * oma) >> 8;
    CHECK(mixr >= 0);
    CHECK(mixg >= 0);
    CHECK(mixb >= 0);
    CHECK(mixr <= 255);
    CHECK(mixg <= 255);
    CHECK(mixb <= 255);

    vec[y * ww * 4 + x * 4 + 0] = mixr;
    vec[y * ww * 4 + x * 4 + 1] = mixg;
    vec[y * ww * 4 + x * 4 + 2] = mixb;
    vec[y * ww * 4 + x * 4 + 3] = 0xFF;
  }

  void BlitGraphicRect(const Graphic &graphic,
		       int rectx, int recty,
		       int rectw, int recth,
		       int dstx, int dsty) {
    BlitAlpha(graphic.width, graphic.height, rectx, recty,
	      rectw, recth, dstx, dsty,
	      graphic.rgba);
  }

  void BlitGraphic(const Graphic &graphic,
		   int dstx, int dsty) {
    BlitAlpha(graphic.width, graphic.height, 0, 0,
	      graphic.width, graphic.height, dstx, dsty,
	      graphic.rgba);
  }

  // Blit(256, 256, 0, 0, 256, 200, 0, 50, screens[i]);
  // Copies alpha component from src.
  void Blit(int srcwidth, int srcheight,
	    int rectx, int recty,
	    int rectw, int recth,
	    int dstx, int dsty,
	    const vector<uint8> &srcrgba) {
    for (int y = 0; y < recth; y++) {
      for (int x = 0; x < rectw; x++) {
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

  // Blends using source alpha, assuming dst alpha is 1.
  void BlitAlpha(int srcwidth, int srcheight,
		 int rectx, int recty,
		 int rectw, int recth,
		 int dstx, int dsty,
		 const vector<uint8> &srcrgba) {
    for (int y = 0; y < recth; y++) {
      for (int x = 0; x < rectw; x++) {
	uint32 r, g, b, a;

	r = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 0];
	g = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 1];
	b = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 2];
	a = srcrgba[(y + recty) * srcwidth * 4 + (x + rectx) * 4 + 3];

	if (a != 0xFF) {
	  uint32 old = GetPixel(dstx + x, dsty + y);
	  uint32 oldr = 0xFF & (old >> 24);
	  uint32 oldg = 0xFF & (old >> 16);
	  uint32 oldb = 0xFF & (old >>  8);
	  uint32 oma = 0xFF - a;
	  
	  // Each value was multiplied by 256 (max alpha),
	  // so divide to put in range again. Since we are
	  // blending with (1-a) and all integer, there's 
	  // no possibility of overflow.
	  uint32 mixr = (r * a + oldr * oma) >> 8;
	  uint32 mixg = (g * a + oldg * oma) >> 8;
	  uint32 mixb = (b * a + oldb * oma) >> 8;

	  WritePixel(dstx + x, dsty + y, mixr, mixg, mixb, 0xFF);
	} else {
	  WritePixel(dstx + x, dsty + y, r, g, b, 0xFF);
	}
      }
    }
  }

  struct Score {
    static const int SCOREH = 32;
    Score(int green, int red, int blue) 
      : green(green), red(red), blue(blue) {}
    int green;
    int red;
    int blue;
  };

  Score GetScore(const vector<ObjFact> &objfacts) {
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

    int green = floor((gtotal / total) * Score::SCOREH);
    int red = floor((rtotal / total) * Score::SCOREH);
    int blue = Score::SCOREH - red - green;
    return Score(green, red, blue);
  }

  void WriteScoreTo(int xstart, int ystart,
		    Score score, int width) {
    for (int y = 0; y < Score::SCOREH; y++) {
      uint8 r, g, b;
      if (y < score.blue) {
	r = g = 0;
	b = 0x7F;
      } else if (y < score.blue + score.red) {
	b = g = 0;
	r = 0xCC;
      } else {
	r = b = 0;
	g = 0xCC;
      }
      for (int x = 0; x < width; x++) {
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

  void WriteNormalizedTo(int x, int y, 
			 const vector< vector<uint8> > &memories,
			 const vector<uint32> &colors,
			 // Index of most recent memory to look at.
			 int now,
			 int width, int height,
			 int surfw, int surfh,
			 uint8 *surf) {
    // consider using non-linear window into past
    for (int col = 0; col <= width; col++) {
      // Which memory?
      int idx = now - col;
      if (idx < 0) break;
      const vector<uint8> &mem = memories[idx];
      vector<double> vfs = objectives->GetNormalizedValues(mem);
      CHECK(vfs.size() == colors.size());
      for (int i = 0; i < vfs.size(); i++) {
	CHECK(0.0 <= vfs[i]);
	CHECK(vfs[i] <= 1.0);

	const uint32 color = colors[i];
	uint8 r = 255 & (color >> 24);
	uint8 g = 255 & (color >> 16);
	uint8 b = 255 & (color >> 8);

	if (fatobjectivelines) {
	  double omv = 1.0 - vfs[i];
	  double point = height * omv;
	  // Number of pixels between edge pixels.
	  // Nominal width is NP + 1.
	  static const int NP = 3;
	  int start = floor(point);
	  double leftover = point - start;
	  CHECK(leftover >= 0.0);
	  CHECK(leftover <= 1.0);
	  uint8 endalpha = leftover * 255;
	  uint8 startalpha = 255 - endalpha;
	  CHECK(((uint32)endalpha + (uint32)startalpha) == 255);

	  #if 0
	  printf("col %d  point %f  start %d   alpha %d - %d\n",
		 col,
		 point, start, startalpha, endalpha);
	  #endif

	  // Always draw faint startpixel, but after
	  // that we may need to clip.
	  WritePixelAlphaTo(x + col, y + start,
			    r, g, b, startalpha,
			    surf, surfw, surfh);
	  for (int p = 1; p <= NP; p++) {
	    if (start + p >= height) break;
	    WritePixelTo(x + col, y + start + p,
			 r, g, b,
			 surf, surfw, surfh);
	  }
	  if (start + NP + 1 < height) {
	    WritePixelAlphaTo(x + col, y + start + NP + 1,
			      r, g, b, endalpha,
			      surf, surfw, surfh);
	  }

	} else {
	  double yoff = height * (1.0 - vfs[i]);
	  WritePixelTo(x + col, y + floor(yoff), 
		       r, g, b, surf, surfw, surfh);
	}
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

  void DrawController(int x, int y, uint8 input) {
    // Draw the regular controller first.
    BlitGraphic(controller, x, y);

    // Then the one with buttons pressed, in the region for each
    // button.
    if (input & INPUT_R) {
      BlitGraphicRect(controllerdown, 9, 8, 5, 6, x + 9, y + 8);
    }
    if (input & INPUT_L) {
      BlitGraphicRect(controllerdown, 2, 8, 5, 6, x + 2, y + 8);
    }
    if (input & INPUT_D) {
      BlitGraphicRect(controllerdown, 5, 12, 6, 5, x + 5, y + 12);
    }
    if (input & INPUT_U) {
      BlitGraphicRect(controllerdown, 5, 5, 6, 5, x + 5, y + 5);
    }

    if (input & INPUT_T) {
      BlitGraphicRect(controllerdown, 23, 12, 7, 4, x + 23, y + 12);
    }
    if (input & INPUT_S) {
      BlitGraphicRect(controllerdown, 16, 12, 7, 4, x + 16, y + 12);
    }

    if (input & INPUT_B) {
      BlitGraphicRect(controllerdown, 32, 10, 7, 7, x + 32, y + 10);
    }
    if (input & INPUT_A) {
      BlitGraphicRect(controllerdown, 40, 10, 7, 7, x + 40, y + 10);
    }
  }

  void WriteScoreAndHistoryTo(int x, int y, const vector<ObjFact> &objfacts,
			      vector<Score> *history,
			      int width) {
    Score score = GetScore(objfacts);
    WriteScoreTo(x, y, score, 6);
    width -= 7;
    for (int i = 0; i < width; i++) {
      if (i >= history->size()) break;
      
      const int fromback = (history->size() - 1) - i;
      WriteScoreTo(x + 7 + i, y, history->at(fromback), 1);
    }
    history->push_back(score);
  }

  void SaveAV(const string &dir) {
    // Represents the memory BEFORE each frame. Will be one
    // larger than the movie size.
    vector< vector<uint8> > memories;
    // Screen AFTER each frame.
    vector< vector<uint8> > screens;

    // XXX inline, rename
    const int STARTFRAMES = startframe;
    const int MAXFRAMES = maxframe;

    const string wavename = StringPrintf("%s/%s-%d-%d.wav",
					 dir.c_str(),
					 game.c_str(),
					 STARTFRAMES, MAXFRAMES);
    WaveFile wavefile(wavename);

    // Come up with colors.
    vector<uint32> colors;
    ArcFour rc("scopefun");
    for (int i = 0; i < objectives->Size(); i++) {
      colors.push_back(RandomBrightColor(&rc));
    }

    // True once an input has been nonempty.
    bool started = false;

    for (int i = 0; i < movie.size() && i < MAXFRAMES + 2; i++) {
      vector<uint8> mem, screen;
      Emulator::GetMemory(&mem);
      memories.push_back(mem);

      // Values.
      if (started) objectives->Observe(mem);

      if (i % 100 == 0) fprintf(stderr, "%d.\n", i);
      Emulator::StepFull(movie[i]);
      // Once we've pressed a button, we've started.
      if (movie[i]) started = true;

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
      if (started) objectives->Observe(mem_last);
    }

    wavefile.Close();
    fprintf(stderr, "Wrote sound.\n");

    if (soundonly) return;

    uint64 starttime = time(NULL);

    vector<Score> comp_one, comp_ten, comp_hundred;
    for (int i = STARTFRAMES; i < movie.size() && i < MAXFRAMES; i++) {
      ClearBuffer();

      // Blit(256, 256, 0, 0, 128, 64, 0, 128, screens[i]);
      // n.b. real height of output video is only 240 pixels.
      // After that isn't even interesting overscan, just a
      // constant pattern.
      static const int NESHEIGHT = 240;
      Blit(256, 256, 0, 0, 256, NESHEIGHT, 0, 0, screens[i]);

      // Controller.
      DrawController(16, height - (controller.height + 9), movie[i]);

      // Previous frame.
      {
	vector<MemFact> facts;
	vector<ObjFact> objfacts;
	double total_weight = 0;
	MakeMemFacts(memories[i], memories[i + 1],
		     &facts, &objfacts, &total_weight);
	WriteRAMTo(257, 0, memories[i + 1], facts, total_weight);

	WriteScoreAndHistoryTo(257 + 65, 0, objfacts, &comp_one, 156);
      }
      
      // Ten frames.
      if (i > 10) {
	vector<MemFact> facts;
	vector<ObjFact> objfacts;

	double total_weight = 0;
	MakeMemFacts(memories[i - 9], memories[i + 1],
		     &facts, &objfacts, &total_weight);
	WriteRAMTo(257, 33, memories[i + 1], facts, total_weight);
	WriteScoreAndHistoryTo(257 + 65, 33, objfacts, &comp_ten, 156);
      }

      // One hundred frames.
      if (i > 100) {
	vector<MemFact> facts;
	vector<ObjFact> objfacts;

	double total_weight = 0;
	MakeMemFacts(memories[i - 99], memories[i + 1], 
		     &facts, &objfacts, &total_weight);
	WriteRAMTo(257, 66, memories[i + 1], facts, total_weight);
	Score score = GetScore(objfacts);
	WriteScoreAndHistoryTo(257 + 65, 66, objfacts, &comp_hundred, 156);
      }

      CopyTo4x();

      // WriteNormalizedTo(257, 99, memories, colors, i, 222, 156);
      WriteNormalizedTo(257 * 4, 99 * 4, memories, colors, i, 222 * 4, 156 * 4,
			width * 4, height * 4, rgba4x);

     
      const string filename = StringPrintf("%s/%s-%d.png",
					   dir.c_str(), game.c_str(), i);

      Save4x(filename);
      int totalframes = min((int)movie.size(), MAXFRAMES) - STARTFRAMES;
      double seconds_elapsed = time(NULL) - starttime;
      double fps = (i - STARTFRAMES) / seconds_elapsed;
      double seconds_left = (totalframes - i) / fps;
      fprintf(stderr, "Wrote %s (%.1f%% / %.1fm left).\n",
	      filename.c_str(),
	      (100.0 * (i - STARTFRAMES)) / totalframes,
	      seconds_left / 60.0);
    }

    fprintf(stderr, "Done.\n");
  }

  int startframe, maxframe;

  // 1/4 HD = 480x270
  static const int width = 480;
  static const int height = 270;
  uint8 rgba[width * height * 4];
  uint8 *rgba4x;

  Graphic controller, controllerdown;

  WeightedObjectives *objectives;
  string game;
  vector<uint8> movie;
  const bool soundonly;
  const bool fatobjectivelines;
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
  bool soundonly = !config["soundonly"].empty();
  bool fatobjectivelines = !config["fatobjectivelines"].empty();

  ScopeFun pf(game, moviename, startframe, maxframe, soundonly,
	      fatobjectivelines);
  string dir = game + "-movie";
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
