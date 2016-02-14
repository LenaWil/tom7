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
#include <GL/gl.h>
#include <GL/glext.h>

#include "matrices.h"

#define WIDTH 1920
#define HEIGHT 1080
static constexpr double ASPECT_RATIO = WIDTH / (double)HEIGHT;

typedef void (APIENTRY *glWindowPos2i_t)(int, int);
glWindowPos2i_t glWindowPos2i = nullptr;
static void GetExtensions() {
  #define INSTALL(s) \
    CHECK((s = (s ## _t)SDL_GL_GetProcAddress(# s))) << s;
  INSTALL(glWindowPos2i);
}

static GLubyte red[]     = { 255,   0,   0, 255 };
static GLubyte green[]   = {   0, 255,   0, 255 };
static GLubyte blue[]    = {   0,   0, 255, 255 };
static GLubyte white[]   = { 255, 255, 255, 255 };
static GLubyte cyan[]    = {   0, 255, 255, 255 };
static GLubyte black[]   = {   0,   0,   0, 255 };
static GLubyte yellow[]  = { 255, 255,   0, 255 };
static GLubyte magenta[] = { 255,   0, 255, 255 };


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
  

  float roll = 0.0f, pitch = 0.0f, yaw = 0.0f;

  float xlatx = 0.0f, xlaty = 0.0f, xlatz = -50.0;
  
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
	  case SDLK_q: roll += 0.1f; break;
	  case SDLK_a: roll -= 0.1f; break;
	  case SDLK_w: pitch += 0.1f; break;
	  case SDLK_s: pitch -= 0.1f; break;
	  case SDLK_e: yaw += 0.1f; break;
	  case SDLK_d: yaw -= 0.1f; break;

	  case SDLK_UP: xlaty += 0.05f; break;
	  case SDLK_DOWN: xlaty -= 0.05f; break;
	  case SDLK_LEFT: xlatx -= 0.05f; break;
	  case SDLK_RIGHT: xlatx += 0.05f; break;

	  case SDLK_KP_MINUS:
	  case SDLK_MINUS: xlatz -= 0.05; break;
	  case SDLK_KP_PLUS:
	  case SDLK_EQUALS:
	  case SDLK_PLUS: xlatz += 0.05; break;	    
	    
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
	  
	BlitNESGL(image, 0, HEIGHT);

	vector<Vec3> boxes = GetBoxes();
	DrawScene(boxes);

	// DrawPPU();
	// DrawScene();
	// Benchmark();

	SDL_GL_SwapBuffers( );

	if (frame % 1000 == 0) {
	  int now = SDL_GetTicks();
	  printf("%d frames in %d ms = %f fps.\n",
		 frame, (now - start),
		 frame / ((now - start) / 1000.0f));
	}
      }
    }
  }
  
  // Draw the 256x256 NES image at the specified coordinates (0,0 is
  // bottom left).
  void BlitNESGL(const vector<uint8> &image, int x, int y) {
    glPixelZoom(1.0f, -1.0f);
    (*glWindowPos2i)(x, y);
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
	} else if (type == FLOOR) {
	  z = 0.0f;
	  continue;
	} else if (type == UNMAPPED) {
	  z = 1.0f;
	}
	ret.push_back(Vec3{(float)x, (float)y, z});
      }
    }
    return ret;
  }

  void DrawScene(const vector<Vec3> &boxes) {
    // printf("There are %d boxes.\n", (int)boxes.size());
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    // Move camera.
    glTranslatef(xlatx, xlaty, xlatz);

    // nb. just picked these names arbitrarily
    glRotatef(yaw, 0.0, 1.0, 0.0);
    glRotatef(pitch, 1.0, 0.0, 0.0);
    glRotatef(roll, 0.0, 0.0, 1.0);

    glBegin(GL_TRIANGLES);
	
    // Draw boxes as a bunch of triangles.
    //  {Vec3{1.0, 0.0, 0.0}, Vec3{2.0, 0.0, 0.0}}
    for (const Vec3 &v : boxes) {
      //      a-----b
      //     /:    /|
      //    c-----d |
      //    | :   | |
      //    | e---|-f
      //    |/    |/
      //    g-----h

      Vec3 a = v;
      Vec3 b = Vec3Plus(v, Vec3{1.0f, 0.0f, 0.0f});
      Vec3 c = Vec3Plus(v, Vec3{0.0f, 1.0f, 0.0f});
      Vec3 d = Vec3Plus(v, Vec3{1.0f, 1.0f, 0.0f});
      Vec3 e = Vec3Plus(v, Vec3{0.0f, 0.0f, 1.0f});
      Vec3 f = Vec3Plus(v, Vec3{1.0f, 0.0f, 1.0f});
      Vec3 g = Vec3Plus(v, Vec3{0.0f, 1.0f, 1.0f});
      Vec3 h = Vec3Plus(v, Vec3{1.0f, 1.0f, 1.0f});
      
      auto CCWFace = [](const Vec3 &a, const Vec3 &b, const Vec3 &c, const Vec3 &d) {
	//
	//  d----c
	//  | 1 /|
	//  |  / |
	//  | /  |
	//  |/ 2 |
	//  a----b
	//

	glVertex3fv(a.Floats());
	glVertex3fv(c.Floats());
	glVertex3fv(d.Floats());

	glVertex3fv(a.Floats());
	glVertex3fv(b.Floats());
	glVertex3fv(c.Floats());
      };

      // Top
      glColor4ubv(red);
      CCWFace(c, d, b, a);

      // Front
      glColor4ubv(magenta);
      CCWFace(g, h, d, c);
      // Back
      glColor4ubv(magenta);
      CCWFace(f, e, a, b);


      // Right
      glColor4ubv(green);
      CCWFace(h, f, b, d);

      // Left
      glColor4ubv(green);
      CCWFace(e, g, c, a);

      // Bottom
      glColor4ubv(yellow);
      CCWFace(e, f, h, g);
    }

    glEnd();
  }
  
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

  // Probably no need for backface culling except perhaps if the
  // camera gets inside walls, but turn it on anyway...
  glCullFace(GL_BACK);
  glFrontFace(GL_CCW);
  glEnable(GL_CULL_FACE);

  glClearColor(0, 0, 0, 0);

  // Set up the screen. Recall that (0,0) is the bottom-left corner,
  // not the top-left.
  glViewport(0, 0, WIDTH, HEIGHT);

  glEnable(GL_DEPTH_TEST);
  
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();

  PerspectiveGL(60.0, ASPECT_RATIO, 1.0, 1024.0);

  GetExtensions();
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

  if (bpp != 32) {
    fprintf(stderr, "This probably won't work unless BPP is "
	    "32, but I got %d from SDL.\n", bpp);
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
