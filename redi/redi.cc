#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>

#include "base/stringprintf.h"
#include "base/logging.h"
#include "arcfour.h"
#include "util.h"
#include "timer.h"
#include "stb_image.h"
#include "stb_image_write.h"
#include "stb_truetype.h"

#include "threadutil.h"
#include "clutil.h"

#include "constants.h"

using namespace std;

// Little byte machine.
using uint8 = uint8_t;
// Better compatibility with CL.
using uchar = uint8_t;

using uint64 = uint64_t;

// You can read the previous versions (redi-random.cc) to see some of
// the history / thoughts.

static_assert((NPP >= 3), "Must have at least R, G, B pixels.");
static_assert((NEIGHBORHOOD & 1) == 1, "neighborhood must be odd.");
static_assert((NUM_NODES % CHUNK_SIZE) == 0, "chunk size must divide input.");

static_assert(RANDOM == 0, "random not yet supported.");

struct ImageRGBA {
  static ImageRGBA *Load(const string &filename) {
    vector<uint8> ret;
    int width, height, bpp_unused;
    uint8 *stb_rgba = stbi_load(filename.c_str(), 
				&width, &height, &bpp_unused, 4);
    const int bytes = width * height * 4;
    ret.resize(bytes);
    if (stb_rgba == nullptr) return nullptr;
    memcpy(ret.data(), stb_rgba, bytes);
    // Does this move image data all the way in, or do we need to
    // write a move constructor manually? Better way?
    return new ImageRGBA(std::move(ret), width, height);
  }

  ImageRGBA(const vector<uint8> &rgba, int width, int height) 
    : width(width), height(height), rgba(rgba) {
    CHECK(rgba.size() == width * height * 4);
  }

  void Save(const string &filename) {
    CHECK(rgba.size() == width * height * 4);
    stbi_write_png(filename.c_str(), width, height, 4, rgba.data(), 4 * width);
  }

  // TODO:: Save a vector of images of the same size in a grid.
  const int width, height;
  vector<uint8> rgba;
};

// Single-channel bitmap.
struct ImageA {
  ImageA(const vector<uint8> &alpha, int width, int height)
    : width(width), height(height), alpha(alpha) {
    CHECK(alpha.size() == width * height);
  }
  const int width, height;
  vector<uint8> alpha;
};

// Pretty much only useful for this application since it loads the whole font each time.
ImageA *FontChar(const string &filename, char c, int size) {
  printf("Fopen...\n");
  fflush(stdout);

  FILE *file = fopen(filename.c_str(), "rb");
  if (file == nullptr) {
    fprintf(stderr, "Failed to fopen %s\n", filename.c_str());
    return nullptr;
  }
  printf("fopen ok\n");
  // XXX check read size
  uint8 *ttf_buffer = (uint8*)malloc(1<<25);
  fread(ttf_buffer, 1, 1 << 25, file);
  fclose(file);
  printf("Fread ok.\n");

  stbtt_fontinfo font;
  stbtt_InitFont(&font, ttf_buffer, stbtt_GetFontOffsetForIndex(ttf_buffer, 0));
  int width, height;
  uint8 *bitmap = stbtt_GetCodepointBitmap(&font, 0, stbtt_ScaleForPixelHeight(&font, size),
					   c, &width, &height, 0, 0);
  if (bitmap == nullptr) {
    fprintf(stderr, "Failed to getcodepoint\n");
    free(ttf_buffer);
    return nullptr;
  }
  const int bytes = width * height;
  vector<uint8> ret;
  ret.resize(bytes);
  memcpy(ret.data(), bitmap, bytes);
  free(ttf_buffer);
  return new ImageA(ret, width, height);
}

void BlitChannel(uint8 r, uint8 g, uint8 b, const ImageA &channel, 
		 int xpos, int ypos,
		 ImageRGBA *dest) {
  for (int y = 0; y < channel.height; y++) {
    int dsty = ypos + y;
    if (dsty >= 0 && dsty < dest->height) {
      for (int x = 0; x < channel.width; x++) {
	int dstx = xpos + x;
	if (dstx >= 0 && dstx <= dest->width) {
	  int sidx = x + channel.width * y;
	  int ch = channel.alpha[sidx];

	  auto Blend = [&dest](int idx, uint8 val, uint8 a) {
	    uint8 old = dest->rgba[idx];
	    uint8 oma = 0xFF - a;
	    uint8 replacement = ((oma * (int)old) + (a * (int)val)) >> 8;
	    dest->rgba[idx] = replacement;
	  };

	  int didx = dstx * 4 + (dsty * dest->width) * 4;
	  Blend(didx + 0, r, ch);
	  Blend(didx + 1, g, ch);
	  Blend(didx + 2, b, ch);
	  dest->rgba[didx + 3] = 0xFF;
	  /*
	  dest->rgba[didx + 0] = r;
	  dest->rgba[didx + 1] = g;
	  dest->rgba[didx + 2] = b;
	  dest->rgba[didx + 3] = ch;
	  */
	}
      }
    }
  }
}

int main(int argc, char* argv[])  {
  Timer setup_timer;
  ArcFour rc("redi");
  rc.Discard(2000);

  auto RandFloat = [&rc]() -> float {
    // XXX does this have the same precision problem that I had in the CL code?
    uint32 uu = 0u;
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    return (float)(uu / (double)0xFFFFFFFF);
  };
  (void)RandFloat;


  auto Rand64 = [&rc]() -> uint64 {
    uint64 uu = 0ULL;
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    return uu;
  };
  (void)Rand64;

  /*
  printf("[GPU] Initializing GPU.\n");
  
  const string kernel_src = 
    Util::ReadFile("constants.h") + "\n" +
    Util::ReadFile("evaluate.cl");
  */

  CL cl;

  vector<string> filenames = 
    // So gratuitous to use parallel map here..
    ParallelMap(Util::ListFiles("corpus256/"),
		[](const string &s) -> string { return (string)"corpus256/" + s; },
		8);

  printf("Loading %d...\n", (int)filenames.size());
  vector<ImageRGBA *> corpus =
    ParallelMap(filenames,
		[](const string &s) { return ImageRGBA::Load(s); },
		16);
  CHECK(corpus.size() > 0);

  vector<string> font_filenames = Util::ListFiles("fonts/");
  vector<ImageA *> fonts =
    ParallelMap(font_filenames,
		[](const string &s) { 
		  Image *f = ImageA::Load((string)"fonts/" + s); 
		  CHECK(f != nullptr) << s;
		  return f;
		},
		16);
  CHECK(fonts.size() > 0);

  BlitChannel(0xFF, 0x0, 0x0, *font, 
	      30, 30,
	      corpus[0]);

  printf("Save it..\n");
  corpus[0]->Save("testi.png");

  printf("Done.\n");

  return 0;
}
