
#include "arst.h"

#include <stdio.h>
#include <utility>

#include "sdlutil-lite.h"
#include "time.h"
#include "SDL.h"
#include "SDL_main.h"
#include "../cc-lib/util.h"
#include "../cc-lib/stb_image.h"

// original file size
#define FRAMEWIDTH 480
#define FRAMEHEIGHT 270
// XXX more like 200k
// filenames are 0 - (NUM_FRAMES - 1)
#define NUM_FRAMES 179633

// XXX add UI
#define WIDTH (FRAMEWIDTH * 2)
#define HEIGHT (FRAMEHEIGHT * 2)

#define SWAB 1

SDL_Surface *screen = 0;

static string FrameFilename(int f) {
  return StringPrintf("d:\\video\\starwars_quarterframes\\s%06d.jpg", f);
}

struct Frame {
  // Store compressed frames.
  vector<uint8> bytes;
};

// Global for easier thread access.
vector<Frame> frames;
static void InitializeFrames() {
  frames.resize(NUM_FRAMES);  
}

static void ReadFileBytes(const string &f, vector<uint8> *out) {
  string s = Util::ReadFile(f);
  CHECK(!s.empty());
  out->clear();
  out->reserve(s.size());
  // PERF memcpy
  for (int i = 0; i < s.size(); i++) {
    out->push_back((uint8)s[i]);
  }
}

static int LoadFrameThread(void *vdata) {
  pair<int, int> *data = (pair<int, int> *)vdata;
  printf("Started LFT %d\n", data->first);
  for (int f = data->first; f < data->second; f++) {
    const string fname = FrameFilename(f);
    // printf ("... %s\n", fname.c_str());
    ReadFileBytes(fname, &frames[f].bytes);
  }
  printf("Finishing LFT %d\n", data->first);
  return 0;
}

// assumes RGBA, surfaces exactly the same size, etc.
static void CopyRGBA(const vector<uint8> &rgba, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, &rgba[0], surface->w * surface->h * 4);
}

static void CopyRGBA2x(const vector<uint8> &rgba, SDL_Surface *surface) {
  Uint8 *p = (Uint8 *)surface->pixels;
  const int width = surface->w;
  CHECK((width & 1) == 0);
  const int halfwidth = width >> 1;
  const int height = surface->h;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int idx = (y * width + x) * 4;
      int hidx = ((y >> 1) * halfwidth + (x >> 1)) * 4;
      #if SWAB
      p[idx + 0] = rgba[hidx + 2];
      p[idx + 1] = rgba[hidx + 1];
      p[idx + 2] = rgba[hidx + 0];
      p[idx + 3] = rgba[hidx + 3];
      #else
      p[idx + 0] = rgba[hidx + 0];
      p[idx + 1] = rgba[hidx + 1];
      p[idx + 2] = rgba[hidx + 2];
      p[idx + 3] = rgba[hidx + 3];
      #endif
    }
  }
}

struct Graphic {
  // From a PNG file.
  explicit Graphic(const vector<uint8> &bytes) {
    int bpp;
    uint8 *stb_rgba = stbi_load_from_memory(&bytes[0], bytes.size(),
					    &width, &height, &bpp, 4);
    CHECK(stb_rgba);
    for (int i = 0; i < width * height * 4; i++) {
      rgba.push_back(stb_rgba[i]);
      //       if (bpp == 3 && (i % 3 == 2)) {
      // rgba.push_back(0xFF);
      //}
    }
    stbi_image_free(stb_rgba);
    if (DEBUGGING)
      fprintf(stderr, "image is %dx%d @%dbpp = %d bytes\n",
	      width, height, bpp,
	      rgba.size());

    surf = sdlutil::makesurface(width * 2, height * 2, true);
    CHECK(surf);
    CopyRGBA2x(rgba, surf);
  }

  // to screen
  void Blit(int x, int y) {
    sdlutil::blitall(surf, screen, x, y);
  }

  ~Graphic() {
    SDL_FreeSurface(surf);
  }

  int width, height;
  vector<uint8> rgba;
  SDL_Surface *surf;
};

struct LabeledFrames {
  LabeledFrames() {
    InitializeFrames();
    LoadFrames();
  }
  
  void LoadFrames() {
    uint64 start = time(NULL);

    static const int FRAMES_PER_THREAD = 20000;
    vector< pair<int, int> > datas;
    vector<string> names;
    for (int i = 0; i < NUM_FRAMES; i += FRAMES_PER_THREAD) {
      datas.push_back(make_pair(i, min(NUM_FRAMES, i + FRAMES_PER_THREAD)));
      names.push_back("lft" + i);
    }
    printf("There will be %lld thread(s)\n", datas.size());

    vector<SDL_Thread *> threads;
    for (int i = 0; i < datas.size(); i++) {
      printf("Spawn thread %d:\n", i);
      threads.push_back(SDL_CreateThread(LoadFrameThread, 
					 // names[i].c_str(),
					 (void*)&datas[i]));
    }

    for (int i = 0; i < threads.size(); i++) {
      int ret_unused;
      SDL_WaitThread(threads[i], &ret_unused);
    }
    printf("%d frames loaded in %lld sec. Bytes used:\n", NUM_FRAMES,
	   time(NULL) - start);

    uint64 bytes_used = 0ULL;
    for (int i = 0; i < frames.size(); i++) {
      bytes_used += frames[i].bytes.size();
    }
    printf("Total bytes used: %.2fmb (%.2fk / frame)\n",
	   (bytes_used / 1000000.0),
	   (bytes_used / (double)frames.size()) / 1000.0);
  }

  void Editor () {
    for (int i = 0; i < frames.size(); i++) {
      Graphic g(frames[i].bytes);
      g.Blit(0, 0);
      SDL_Flip(screen);

      // Ignore events for now
      SDL_Event event;
      SDL_PollEvent(&event);
      switch (event.type) {
      case SDL_QUIT:
	return;
      }

    }
  }
  

};


int SDL_main (int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");

  screen = sdlutil::makescreen(WIDTH, HEIGHT);
  CHECK(screen);

  LabeledFrames lf;
  lf.Editor();

  SDL_Quit();
  return 0;
}
