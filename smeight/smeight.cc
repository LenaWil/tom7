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
#include "../cc-lib/stb_image_write.h"

// XXX make part of Emulator interface
#include "../fceulib/ppu.h"
#include "../fceulib/cart.h"
#include "../fceulib/palette.h"

#include "SDL.h"
#include <GL/gl.h>
#include <GL/glext.h>

#include "matrices.h"

#define WIDTH 1920
#define HEIGHT 1080
static constexpr double ASPECT_RATIO = WIDTH / (double)HEIGHT;

// Size of NES nametable
#define TILESW 32
#define TILESH 30
#define TILEST 32
static_assert(TILEST >= TILESW, "TILEST must hold TILESW");
static_assert(TILEST >= TILESW, "TILEST must hold TILESH");
static_assert(0 == (TILEST & (TILEST - 1)), "TILEST must be power of 2");

// I don't understand why Palette::FCEUD_GetPalette isn't working,
// but the NES palette is basically constant (emphasis aside), so
// let's just inline it to save time. RGB triplets.
static constexpr uint8 ntsc_palette[] = {
  0x80,0x80,0x80, 0x00,0x3D,0xA6, 0x00,0x12,0xB0, 0x44,0x00,0x96,
  0xA1,0x00,0x5E, 0xC7,0x00,0x28, 0xBA,0x06,0x00, 0x8C,0x17,0x00,
  0x5C,0x2F,0x00, 0x10,0x45,0x00, 0x05,0x4A,0x00, 0x00,0x47,0x2E,
  0x00,0x41,0x66, 0x00,0x00,0x00, 0x05,0x05,0x05, 0x05,0x05,0x05,
  0xC7,0xC7,0xC7, 0x00,0x77,0xFF, 0x21,0x55,0xFF, 0x82,0x37,0xFA,
  0xEB,0x2F,0xB5, 0xFF,0x29,0x50, 0xFF,0x22,0x00, 0xD6,0x32,0x00,
  0xC4,0x62,0x00, 0x35,0x80,0x00, 0x05,0x8F,0x00, 0x00,0x8A,0x55,
  0x00,0x99,0xCC, 0x21,0x21,0x21, 0x09,0x09,0x09, 0x09,0x09,0x09,
  0xFF,0xFF,0xFF, 0x0F,0xD7,0xFF, 0x69,0xA2,0xFF, 0xD4,0x80,0xFF,
  0xFF,0x45,0xF3, 0xFF,0x61,0x8B, 0xFF,0x88,0x33, 0xFF,0x9C,0x12,
  0xFA,0xBC,0x20, 0x9F,0xE3,0x0E, 0x2B,0xF0,0x35, 0x0C,0xF0,0xA4,
  0x05,0xFB,0xFF, 0x5E,0x5E,0x5E, 0x0D,0x0D,0x0D, 0x0D,0x0D,0x0D,
  0xFF,0xFF,0xFF, 0xA6,0xFC,0xFF, 0xB3,0xEC,0xFF, 0xDA,0xAB,0xEB,
  0xFF,0xA8,0xF9, 0xFF,0xAB,0xB3, 0xFF,0xD2,0xB0, 0xFF,0xEF,0xA6,
  0xFF,0xF7,0x9C, 0xD7,0xE8,0x95, 0xA6,0xED,0xAF, 0xA2,0xF2,0xDA,
  0x99,0xFF,0xFC, 0xDD,0xDD,0xDD, 0x11,0x11,0x11, 0x11,0x11,0x11,
};

// XXX
static GLuint bg_texture = 0;

typedef void (APIENTRY *glWindowPos2i_t)(int, int);
glWindowPos2i_t glWindowPos2i = nullptr;
static void GetExtensions() {
  #define INSTALL(s) \
    CHECK((s = (s ## _t)SDL_GL_GetProcAddress(# s))) << s;
  INSTALL(glWindowPos2i);
}

enum TileType {
  UNMAPPED = 0,
  FLOOR = 1,
  WALL = 2,
  RUT = 3,
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
      } else if (value == "rut") {
	data[h] = RUT;
      } else {
	printf("Unknown tilemap value: [%s] for %02x\n", value.c_str(), h);
      }
    }
  }
    
  vector<TileType> data{256, UNMAPPED};
};

//           
//           15o
//         |/  
//  270o --+--
//         |
//
// Find the distance (in degrees) to travel clockwise to reach the end
// angle from the start angle. This will always be non-negative, and may
// need to wrap around 0.
static int CWDistance(int start_angle, int end_angle) {
  if (end_angle >= start_angle) {
    return end_angle - start_angle;
  } else {
    return end_angle - start_angle + 360;
  }
}

// Again, always positive.
static int CCWDistance(int start_angle, int end_angle) {
  return CWDistance(end_angle, start_angle);
}

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
    Loop();
    printf("UI shutdown.\n");
  }

  struct Box {
    Vec3 loc;
    int dim;
    int texture_x, texture_y;
  };

  void Loop() {
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    (void)surf;
    int frame = 0;

    int start = SDL_GetTicks();
    
    vector<uint8> start_state = emu->SaveUncompressed();

    int current_angle = 0;

    bool paused = false;
    
    for (;;) {
      printf("Start loop!\n");
      emu->LoadUncompressed(start_state);

      for (int input_idx = 0; input_idx < inputs.size(); input_idx += !paused) {
	const uint8 input = inputs[input_idx];
	frame++;

	SDL_Event event;
	if (0 != SDL_PollEvent(&event)) {
	  switch (event.type) {
	  case SDL_QUIT:
	    return;
	  case SDL_KEYUP:
	    switch (event.key.keysym.sym) {
	    case SDLK_SPACE:
	      paused = !paused;
	      printf("%s.\n", paused ? "paused" : "unpaused");
	      break;
	    default:;
	    }
	    break;

	  case SDL_KEYDOWN:
	    switch (event.key.keysym.sym) {

	    case SDLK_ESCAPE:
	      return;
	    default:;
	    }
	    break;
	  default:;
	  }
	}
	  
	SDL_Delay(1000.0 / 60.0);

	if (!paused) {
	  emu->StepFull(input, 0);
	}

	vector<uint8> image = emu->GetImageARGB();

	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	  
	BlitNESGL(image, 0, HEIGHT);
	
	vector<Box> boxes = GetBoxes();

	uint8 player_x, player_y;
	int player_angle;
	std::tie(player_x, player_y, player_angle) = GetLoc();
	
	// Smooth angle a bit.
	// Maximum degrees to turn per frame.
	static constexpr int MAX_SPIN = 6;
	if (current_angle != player_angle) {
	  // Find the shortest path, which may involve going
	  // through zero.

	  int cw = CWDistance(current_angle, player_angle);
	  int ccw = CCWDistance(current_angle, player_angle);

	  if (cw < ccw) {
	    // Turn clockwise.
	    if (cw < MAX_SPIN) current_angle = player_angle;
	    else current_angle += MAX_SPIN;
	  } else {
	    if (ccw < MAX_SPIN) current_angle = player_angle;
	    else current_angle -= MAX_SPIN;
	  }

	  while (current_angle < 0) current_angle += 360;
	  while (current_angle >= 360) current_angle -= 360;
	}
	DrawScene(boxes, player_x, player_y, current_angle);

	SaveImage();
	
	SDL_GL_SwapBuffers();

	if (frame % 1000 == 0) {
	  int now = SDL_GetTicks();
	  printf("%d frames in %d ms = %f fps.\n",
		 frame, (now - start),
		 frame / ((now - start) / 1000.0f));
	}
      }
    }
  }

  int imagenum = 0;
  bool saving = false;
  void SaveImage() {
    if (!saving) return;
    
    vector<uint8> pixels;
    pixels.resize(WIDTH * HEIGHT * 4);
    glReadPixels(0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
    stbi_write_png(StringPrintf("image_%d.png", imagenum).c_str(),
		   WIDTH, HEIGHT, 4,
		   // Start on last row.
		   pixels.data() + (WIDTH * (HEIGHT - 1)) * 4,
		   // Negative stride to flip during saving.
		   -4 * WIDTH);
    imagenum++;
  }
  
  // Draw the 256x256 NES image at the specified coordinates (0,0 is
  // bottom left).
  void BlitNESGL(const vector<uint8> &image, int x, int y) {
    glPixelZoom(1.0f, -1.0f);
    (*glWindowPos2i)(x, y);
    glDrawPixels(256, 256, GL_BGRA, GL_UNSIGNED_BYTE, image.data());
  }

  // All boxes are 1x1x1. This returns their "top-left" corners. Larger Z is "up".
  //
  //    x=0,y=0 -----> x = TILESW-1 = 31
  //    |
  //    :
  //    |
  //    v
  //   y = TILESH - 1 = 29
  //
  vector<Box> GetBoxes() {
    vector<Box> ret;
    ret.reserve(TILESW * TILESH);
    const uint8 *nametable = emu->GetFC()->ppu->NTARAM;
    const uint8 *palette_table = emu->GetFC()->ppu->PALRAM;
    
    // BG pattern table can be at 0 or 0x1000. For zelda, BG seems
    // to always be at 0x1000, so this is hardcoded for now...
    const uint32 pat_addr = 0x1000;
    const uint8 *vram = &emu->GetFC()->cart->VPage[pat_addr >> 10][pat_addr];

    // The actual BG image, used as a texture for the blocks.
    vector<uint8> bg;
    // Don't bother reserving TILEST size; we'll just copy the portion
    // that might change into the larger texture. (The texture has to
    // have power-of-two dimensions, but not the copied area.)
    bg.resize(TILESW * TILESH * 8 * 8 * 4);

    for (int ty = 0; ty < TILESH; ty++) {
      for (int tx = 0; tx < TILESW; tx++) {
	const uint8 tile = nametable[ty * TILESW + tx];
	
	// Draw to BG.
	// Each tile is made of 8 bytes giving its low color bits, then
	// 8 bytes giving its high color bits.
	const int addr = tile * 16;

	// Attribute byte starts right after tiles in the nametable.
	// First need to figure out which byte it is, based on which
	// square (4x4 tiles).
	const int square_x = tx >> 2;
	const int square_y = ty >> 2;
	const uint8 attrbyte = nametable[TILESW * TILESH + (square_y * (TILESW >> 2)) + square_x];
	// Now get the two bits out of it.
	const int sub_x = (tx >> 1) & 1;
	const int sub_y = (ty >> 1) & 1;
	const int shift = (sub_y * 2 + sub_x) * 2;

	const uint8 attr = (attrbyte >> shift) & 3;
	
	// Decode vram[addr] + vram[addr + 1].
	for (int row = 0; row < 8; row++) {
	  const uint8 row_low = vram[addr + row];
	  const uint8 row_high = vram[addr + row + 8];

	  // bit from msb to lsb.
	  for (int bit = 0; bit < 8; bit++) {
	    const uint8 value =
	      ((row_low >> (7 - bit)) & 1) |
	      (((row_high >> (7 - bit)) & 1) << 1);
	    // Offset with palette table.
	    const uint8 palette_idx = (attr << 2) | value;
	    // ID of global NES color gamut.
	    const uint8 color_id = palette_table[palette_idx];
	    
	    // Put pixel in bg image:

	    const int px = tx * 8 + bit;
	    const int py = ty * 8 + row;
	    const int pixel = (py * TILESW * 8 + px) * 4;
	    bg[pixel + 0] = ntsc_palette[color_id * 3 + 0];
	    bg[pixel + 1] = ntsc_palette[color_id * 3 + 1];
	    bg[pixel + 2] = ntsc_palette[color_id * 3 + 2];
	    bg[pixel + 3] = 0xFF;
	  }
	}


	if (!(tx & 1) && !(ty & 1)) {
	  const TileType type = tilemap.data[tile];
	  float z = 0.0f;
	  if (type == WALL) {
	    z = 2.0f;
	  } else if (type == FLOOR) {
	    z = 0.0f;
	  // continue;
	  } else if (type == RUT) {
	    z = -0.50f;
	  } else if (type == UNMAPPED) {
	    z = 4.0f;
	  }
	  
	  ret.push_back(Box{Vec3{(float)tx, (float)ty, z}, 2, tx, ty});
	}
      }
    }
    
    // Copy background image into bg texture.
    glBindTexture(GL_TEXTURE_2D, bg_texture);
    glTexSubImage2D(GL_TEXTURE_2D, 0,
		    0, 0, TILESW * 8, TILESH * 8,
		    GL_RGBA, GL_UNSIGNED_BYTE,
		    bg.data());
    
    return ret;
  }

  void DrawScene(const vector<Box> &orig_boxes,
		 int player_x, int player_y,
		 int player_angle) {
    // Put boxes in GL space where Y=0 is bottom-left, not top-left.
    // This also changes the origin of the box itself.
    vector<Box> boxes;
    boxes.reserve(orig_boxes.size());
    for (const Box &box : orig_boxes) {
      boxes.push_back(Box{Vec3{box.loc.x, (float)(TILESH - 1) - box.loc.y, box.loc.z},
	    box.dim,
	    box.texture_x, box.texture_y});
    }

    // printf("There are %d boxes.\n", (int)boxes.size());
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    // Put player on ground with top of screen straight ahead.
    glRotatef(-90.0f, 1.0, 0.0, 0.0);

    // Rotate according to the direction the player is facing.
    glRotatef(player_angle, 0.0, 0.0, 1.0);
    
    // Move "camera".
    glTranslatef(player_x / -8.0f,
		 ((TILESH * 8 - 1) - player_y) / -8.0f,
		 // 3/4 of a 4x4 block height
		 -3.0f);

    // XXX don't need this
    glBegin(GL_LINE_STRIP);
    glVertex3f(0.0f, 0.0f, 0.0f);
    glVertex3f((float)TILESW, 0.0f, 0.0f);
    glVertex3f((float)TILESW, (float)TILESH, 0.0f);
    glVertex3f(0.0f, (float)TILESH, 0.0f);
    glVertex3f(0.0f, 0.0f, 0.0f);
    glEnd();
    
    glEnable(GL_TEXTURE_2D);
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);

    // One texture for the whole scene.
    glBindTexture(GL_TEXTURE_2D, bg_texture);
    glBegin(GL_TRIANGLES);
    
    // Draw boxes as a bunch of triangles.
    for (const Box &box : boxes) {
      // Here, boxes are properly oriented in GL axes, like this. The
      // input vector is the front bottom left corner, a:
      //
      //      g-----h
      //     /:    /|              ^   7
      //    d-----c |            + |  / +
      //    | :   | |            z | / y
      //    | f---|-e            - |/ -
      //    |/    |/               0------->
      //    a-----b                  -x+
      // (0,0,0)

      const float side = (float)box.dim;
      
      Vec3 a = box.loc;
      Vec3 b = Vec3Plus(a, Vec3{side, 0.0f, 0.0f});
      Vec3 c = Vec3Plus(a, Vec3{side, 0.0f, side});
      Vec3 d = Vec3Plus(a, Vec3{0.0f, 0.0f, side});
      Vec3 e = Vec3Plus(a, Vec3{side, side, 0.0f});
      Vec3 f = Vec3Plus(a, Vec3{0.0f, side, 0.0f});
      Vec3 g = Vec3Plus(a, Vec3{0.0f, side, side});
      Vec3 h = Vec3Plus(a, Vec3{side, side, side});

      // XXX
      const float TD = 8.0f / (8.0f * TILEST);
      const float tx = box.texture_x * TD;
      const float ty = box.texture_y * TD;
      const float tt = box.dim * TD;
      
      // Give bottom left first, and go clockwise.
      auto CCWFace = [tx, ty, tt](const Vec3 &a, const Vec3 &b, const Vec3 &c, const Vec3 &d) {
	//  (0,0) (1,0)
	//    d----c
	//    | 1 /|
	//    |  / |
	//    | /  |
	//    |/ 2 |
	//    a----b
	//  (0,1)  (1,1)  texture coordinates

	glTexCoord2f(tx,      ty + tt); glVertex3fv(a.Floats());
	glTexCoord2f(tx + tt, ty);      glVertex3fv(c.Floats());
	glTexCoord2f(tx,      ty);      glVertex3fv(d.Floats());

	glTexCoord2f(tx,      ty + tt); glVertex3fv(a.Floats());
	glTexCoord2f(tx + tt, ty + tt); glVertex3fv(b.Floats());
	glTexCoord2f(tx + tt, ty);      glVertex3fv(c.Floats());
      };

      // Top
      // glColor4ubv(red);
      CCWFace(d, c, h, g);

      // Front
      // glColor4ubv(magenta);
      CCWFace(a, b, c, d);

      // Back
      // glColor4ubv(magenta);
      CCWFace(e, f, g, h);

      // Right
      // glColor4ubv(green);
      CCWFace(b, e, h, c);

      // Left
      // glColor4ubv(green);
      CCWFace(f, a, d, g);

      // Bottom
      // glColor4ubv(yellow);
      CCWFace(f, e, b, a);

    }

    glEnd();
    glDisable(GL_TEXTURE_2D);
  }

  // x, y, angle (deg, where 0 is north)
  std::tuple<uint8, uint8, int> GetLoc() {
    vector<uint8> ram = emu->GetMemory();
    
    uint8 dir = ram[0x98];

    // Link's top-left corner, so add 8,8 to get center.
    uint8 lx = ram[0x70] + 8, ly = ram[0x84] + 8;

    int angle = 0;
    switch (dir) {
    case 1: angle = 90; break;
    case 2: angle = 270; break;
    case 4: angle = 180; break;
    case 8: angle = 0; break;
    default:;
    }

    return make_tuple(lx, ly, angle);
  }
  
 private:
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
  
  glEnable(GL_MULTISAMPLE);
  
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();

  // Allocate one bg texture.
  {
    glGenTextures(1, &bg_texture);
    glBindTexture(GL_TEXTURE_2D, bg_texture);
    vector<uint8> bg;
    bg.resize(8 * 8 * TILEST * TILEST * 4);
    // PERF is RGBA a good choice? It aligns better but does it make
    // blitting much more costly because of the (unused) alpha channel?
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 256, 0,
		 GL_RGBA, GL_UNSIGNED_BYTE, bg.data());
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // No good answer here. Just make sure to hit pixels exactly.
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  }
  
  
  PerspectiveGL(60.0, ASPECT_RATIO, 1.0, 1024.0);

  GetExtensions();
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0) << SDL_GetError();

  const SDL_VideoInfo *info = SDL_GetVideoInfo();
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

  // 2x MSAA -- doesn't do much though since the textures
  // are still linear interpolation. Should instead render
  // offscreen and then downsample.
  SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
  
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
