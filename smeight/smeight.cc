#include <vector>
#include <string>
#include <set>
#include <memory>

#include <cstdio>
#include <cstdlib>
#include <cmath>

#include "smeight.h"

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"
#include "../cc-lib/sdl/sdlutil.h"
#include "../cc-lib/util.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/stb_image.h"
#include "../cc-lib/sdl/chars.h"
#include "../cc-lib/sdl/font.h"
#include "../cc-lib/randutil.h"

// XXX make part of Emulator interface
#include "../fceulib/ppu.h"

#include "SDL.h"
// GL before GLEW, never flew
// GLEW before GL, never hell
#include <GL/glew.h>
#include <GL/gl.h>

#include "matrices.h"


#define WIDTH 1920
#define HEIGHT 1080
static constexpr double ASPECT_RATIO = WIDTH / (double)HEIGHT;

// XXX gone with GL?
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

enum TileType {
  UNMAPPED = 0,
  FLOOR = 1,
  WALL = 2,
};

struct Tilemap {
  Tilemap() {}
  explicit Tilemap(const string &filename) {
    vector<string> lines = Util::ReadFileToLines(filename);
    for (string line : lines) {
      string key = Util::chop(line);
      if (key.empty() || key[0] == '#') continue;
      
      if (key.size() != 2 || !Util::IsHexDigit(key[0]) || !Util::IsHexDigit(key[1])) {
	printf("Bad key in tilemap. Should be exactly 2 hex digits: [%s]\n", key.c_str());
	continue;
      }

      uint8 h = Util::HexDigitValue(key[0]) * 16 + Util::HexDigitValue(key[1]);
      if (data[h] != UNMAPPED) {
	printf("Duplicate keys in tilemap: %02x\n", h);
      }

      string value = Util::chop(line);

      if (value == "wall") {
	data[h] = WALL;
      } else if (value == "floor") {
	data[h] = FLOOR;
      } else {
	printf("Unknown tilemap value: [%s] for %02x\n", value.c_str(), h);
      }
    }
  }
    
  vector<TileType> data{256, UNMAPPED};
};

struct SM {
  std::unique_ptr<Emulator> emu;
  vector<uint8> inputs;
  Tilemap tilemap;
  
  SM() : rc("sm") {
    map<string, string> config = Util::ReadFileToMap("config.txt");
    if (config.empty()) {
      fprintf(stderr, "Missing config.txt.\n");
      abort();
    }

    const string game = config["game"];
    const string tilesfile = config["tiles"];
    const string moviefile = config["movie"];
    CHECK(!game.empty());
    CHECK(!tilesfile.empty());
    
    tilemap = Tilemap{tilesfile};

    // screen = sdlutil::makescreen(WIDTH, HEIGHT);
    // CHECK(screen);

    emu.reset(Emulator::Create(game));
    CHECK(emu.get());

    if (!moviefile.empty()) {
      inputs = SimpleFM2::ReadInputs(moviefile);
      printf("There are %d inputs in %s.\n", (int)inputs.size(), moviefile.c_str());
      const int warmup = atoi(config["warmup"].c_str());
      CHECK(inputs.size() >= warmup);
      // If we have warmup, advance to that point and discard them from inputs.
      for (int i = 0; i < warmup; i++) {
	emu->StepFull(inputs[i], 0);
      }
      inputs.erase(inputs.begin() + 0, inputs.begin() + warmup);
    }

    printf("There are %d inputs left after warmup.\n", (int)inputs.size());
  }

  void Play() {
    /*
    font = Font::create(screen,
			"font.png",
			FONTCHARS,
			FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);
    CHECK(font != nullptr) << "Couldn't load font.";

    smallfont = Font::create(screen,
			     "fontsmall.png",
			     FONTCHARS,
			     SMALLFONTWIDTH, SMALLFONTHEIGHT,
			     FONTSTYLES, 0, 3);
    CHECK(smallfont != nullptr) << "Couldn't load smallfont.";
    */

    Loop();
    printf("UI shutdown.\n");
  }
  

  Vec3 eye{1.0f, 1.0f, 1.0f};
  float roll = 0.0f, pitch = 0.0f, yaw = 0.0f;

  void Loop() {
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    (void)surf;
    int frame = 0;

    int start = SDL_GetTicks();
    
    vector<uint8> start_state = emu->SaveUncompressed();

    for (;;) {
      printf("Start loop!\n");
      emu->LoadUncompressed(start_state);

      for (uint8 input : inputs) {
	frame++;

	SDL_Event event;
	SDL_PollEvent(&event);
	switch (event.type) {
	case SDL_QUIT:
	  return;
	case SDL_KEYDOWN:
	  switch (event.key.keysym.sym) {
	  case SDLK_q: roll += 0.001f; break;
	  case SDLK_a: roll -= 0.001f; break;
	  case SDLK_w: pitch += 0.001f; break;
	  case SDLK_s: pitch -= 0.001f; break;
	  case SDLK_e: yaw += 0.001f; break;
	  case SDLK_d: yaw -= 0.001f; break;
	  case SDLK_y: eye.x += 0.01f; break;
	  case SDLK_h: eye.x -= 0.01f; break;
	  case SDLK_u: eye.y += 0.01f; break;
	  case SDLK_j: eye.y -= 0.01f; break;
	  case SDLK_i: eye.z += 0.005f; break;
	  case SDLK_k: eye.z -= 0.005f; break;
	    
	  case SDLK_ESCAPE:
	    return;
	  default:;
	  }
	  break;
	default:;
	}

	// SDL_Delay(1000.0 / 60.0);

	emu->StepFull(input, 0);

	vector<uint8> image = emu->GetImageARGB();
	// CopyARGB(image, surf);

	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
	  
	BlitNESGL(image, 0, 0);

	// sdlutil::clearsurface(screen, 0x00000000);

	// Draw pixels to screen...
	// sdlutil::blitall(surf, screen, 0, 0);

	// DrawPPU();
	// DrawScene();
	// Benchmark();

	/*
	font->draw(0, HEIGHT - FONTHEIGHT,
		   StringPrintf("roll ^2%f^<  pitch ^2%f^<  yaw ^2%f^<   "
				"ex ^3%f^<  ey ^3%f^<  ez ^3%f^<",
				roll, pitch, yaw, eye.x, eye.y, eye.z));
	*/

	SDL_GL_SwapBuffers( );
	// SDL_Flip(screen);

	if (frame % 100 == 0) {
	  int now = SDL_GetTicks();
	  printf("%d frames in %d ms = %f fps.\n",
		 frame, (now - start),
		 frame / ((now - start) / 1000.0f));
	}
      }
    }
  }
  
  void BlitNESGL(const vector<uint8> &image, int x, int y) {
    // XXX use x, y
    // This is an extension; doesn't work...
    // glWindowPos2i(WIDTH / 2, HEIGHT / 2);
    glDrawPixels(256, 256, GL_BGRA, GL_UNSIGNED_BYTE, image.data());
  }
  
  // All boxes are 1x1x1. This returns their "top-left" corners.
  // All boxes have width 1x1x1.
  // Native coordinates mimic the standard layout on-screen:
  //
  //    x=0,y=0 -----> x = 32
  //    |
  //    :
  //    |
  //    v
  //   y=32
  //
  //    With z going "up" (towards the viewer, looking top-down.)
  vector<Vec3> GetBoxes() {
    vector<Vec3> ret;
    ret.reserve(32 * 32);
    const uint8 *nametable = emu->GetFC()->ppu->NTARAM;
    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
	const uint8 tile = nametable[y * 32 + x];
	const TileType type = tilemap.data[tile];
	float z = 0.0f;
	if (type == WALL) {
	  z = 1.0f;
	  ret.push_back(Vec3{(float)x, (float)y, z});
	} else if (type == FLOOR) {
	  z = 0.0f;
	} else if (type == UNMAPPED) {
	  z = 1.0f;
	}
      }
    }
    return ret;
  }

  #if 0
  void DrawScene() {
    vector<Vec3> boxes = GetBoxes();
    // Transform boxes.

   
    Mat33 mr = RotRoll(roll);
    Mat33 mp = RotPitch(pitch);
    Mat33 my = RotYaw(yaw);
    Mat33 m = Mul33(mr, Mul33(mp, my));

    // XXX move to player center first
    for (Vec3 &v : boxes) {
      v = Mat33TimesVec3(m, v);
    }

    // Scale
    // for (Vec3 &v : boxes) {
    // v = ScaleVec3(v, 32.0f);
    // }

    
    // Map to 2D and draw
    // Now draw vertices.
    auto Draw = [this](const Vec2 &a, const Vec2 &b) {
      if (InfiniteVec2(a) || InfiniteVec2(b))
	return;
      // printf("DCL %f %f %f %f\n", a.x, a.y, b.x, b.y);
      // return;

      Vec2 aa = Vec2Plus(ScaleVec2(a, 16.0f), Vec2{WIDTH / 2.0f, HEIGHT / 2.0f});
      Vec2 bb = Vec2Plus(ScaleVec2(b, 16.0f), Vec2{WIDTH / 2.0f, HEIGHT / 2.0f});
      
      if (sdlutil::clipsegment(0, 0, screen->w - 1, screen->h - 1,
			       aa.x, aa.y, bb.x, bb.y)) {
	sdlutil::drawclipline(screen, aa.x, aa.y, bb.x, bb.y, 0xFF, 0, 0);
      }
    };
    (void)Draw;
    
    auto DrawPt = [this](const Vec2 &a) {
      if (InfiniteVec2(a))
	return;

      Vec2 aa = Vec2Plus(ScaleVec2(a, 16.0f), Vec2{WIDTH / 2.0f, HEIGHT / 2.0f});
      
      sdlutil::drawclippixel(screen, aa.x, aa.y, 0xFF, 0, 0);
    };
    
    for (const Vec3 &v : boxes) {
      //      a-----b
      //     /:    /|
      //    c-----d |
      //    | :   | |
      //    | e---|-f
      //    |/    |/
      //    g-----h

      Vec2 a = Project2D(v, eye);
      Vec2 b = Project2D(Vec3Plus(v, Vec3{1.0f, 0.0f, 0.0f}), eye);
      Vec2 c = Project2D(Vec3Plus(v, Vec3{0.0f, 1.0f, 0.0f}), eye);
      Vec2 d = Project2D(Vec3Plus(v, Vec3{1.0f, 1.0f, 0.0f}), eye);
      Vec2 e = Project2D(Vec3Plus(v, Vec3{0.0f, 0.0f, 1.0f}), eye);
      Vec2 f = Project2D(Vec3Plus(v, Vec3{1.0f, 0.0f, 1.0f}), eye);
      Vec2 g = Project2D(Vec3Plus(v, Vec3{0.0f, 1.0f, 1.0f}), eye);
      Vec2 h = Project2D(Vec3Plus(v, Vec3{1.0f, 1.0f, 1.0f}), eye);

      DrawPt(a);
      DrawPt(b);
      DrawPt(c);
      DrawPt(d);
      DrawPt(e);
      DrawPt(f);
      DrawPt(g);
      DrawPt(h);
      
      #if 0
      Draw(a, b);
      Draw(a, c);
      Draw(a, e);
      Draw(c, d);
      Draw(c, g);
      Draw(b, d);
      Draw(b, f);
      Draw(d, h);
      Draw(e, f);
      Draw(e, g);
      Draw(g, h);
      Draw(f, h);
      #endif
    }
  }
  #endif
  
  #if 0
  // Draws PPU in debug mode.
  void DrawPPU() {
    static constexpr int SHOWY = 0;
    static constexpr int SHOWX = 300;

    vector<uint8> ram = emu->GetMemory();
    
    uint8 *nametable = emu->GetFC()->ppu->NTARAM;
    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
	uint8 tile = nametable[y * 32 + x];
	const char *color = "^2";
	TileType type = tilemap.data[tile];
	if (type == WALL) {
	  color = "";
	} else if (type == FLOOR) {
	  color = "^4";
	} else if (type == UNMAPPED) {
	  color = "^3";
	}
	font->draw(SHOWX + x * FONTWIDTH * 2,
		   SHOWY + y * FONTHEIGHT,
		   StringPrintf("%s%2x", color, tile));
      }
    }

    uint8 dir = ram[0x98];

    // Link's top-left corner, so add 8,8 to get center.
    uint8 lx = ram[0x70] + 8, ly = ram[0x84] + 8;

    float fx = lx / 256.0, fy = ly / 256.0;
    
    int sx = SHOWX + fx * (32 * FONTWIDTH * 2);
    int sy = SHOWY + fy * (32 * FONTHEIGHT);
    sdlutil::drawbox(screen, sx - 4, sy - 4, 8, 8,
		     255, 0, 0);

    switch (dir) {
    case 1:
      // Right
      sdlutil::drawclipline(screen, sx, sy, sx + 8, sy, 255, 128, 0);
      break;
    case 2:
      // Left
      sdlutil::drawclipline(screen, sx, sy, sx - 8, sy, 255, 128, 0);
      break;
    case 4:
      // Down
      sdlutil::drawclipline(screen, sx, sy, sx, sy + 8, 255, 128, 0);
      break;
    case 8:
      // Up
      sdlutil::drawclipline(screen, sx, sy, sx, sy - 8, 255, 128, 0);
      break;
    default:;
    }
  }
  #endif
  
 private:
  static constexpr int FONTWIDTH = 9;
  static constexpr int FONTHEIGHT = 16;
  static constexpr int SMALLFONTWIDTH = 6;
  static constexpr int SMALLFONTHEIGHT = 6;
  
  // Font *font = nullptr, *smallfont = nullptr;
  ArcFour rc;
  NOT_COPYABLE(SM);
};

// Same as gluPerspective, but without depending on GLU.
static void PerspectiveGL(double fovY, double aspect, double zNear, double zFar) {
  static constexpr double pi = 3.1415926535897932384626433832795;
  const double fH = tan(fovY / 360.0 * pi) * zNear;
  const double fW = fH * aspect;
  glFrustum(-fW, fW, -fH, fH, zNear, zFar);
}

static void InitGL() {
  // Pixels!!
  glShadeModel(GL_FLAT);

  // No need for backface culling except perhaps if the camera
  // gets inside walls. There will typically be just 1024 cubes,
  // so there shouldn't be any performance issues, and it requires
  // us to get winding orders corret.
  // glCullFace(GL_BACK);
  // glFrontFace(GL_CCW);
  // glEnable(GL_CULL_FACE);

  glClearColor(0, 0, 0, 0);

  // Set up the screen. Recall that (0,0) is the bottom-left corner,
  // not the top-left.
  glViewport(0, 0, WIDTH, HEIGHT);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();

  PerspectiveGL(60.0, ASPECT_RATIO, 1.0, 1024.0);

  // Init GLEW too.
  GLenum glew_result = glewInit();
  CHECK(glew_result == GLEW_OK) << glewGetErrorString(glew_result);
  fprintf(stderr, "Status: Using GLEW %s\n", glewGetString(GLEW_VERSION));
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0) << SDL_GetError();

  const SDL_VideoInfo *info = SDL_GetVideoInfo( );
  CHECK(info != nullptr) << SDL_GetError();

  const int bpp = info->vfmt->BitsPerPixel;

  if (bpp != 4) {
    fprintf(stderr, "This probably won't work unless BPP is "
	    "4, but I got %d from SDL.\n", bpp);
  }

  // Gimme quality.
  SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
  SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
  SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

  // Can use SDL_FULLSCREEN here for full screen immersive
  // 8 bit action!!
  CHECK(SDL_SetVideoMode(WIDTH, HEIGHT, bpp,
			 SDL_OPENGL)) << SDL_GetError();

  InitGL();
  
  {
    SM sm;
    sm.Play();
  }

  SDL_Quit();
  return 0;
}
