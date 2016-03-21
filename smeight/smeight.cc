#include <algorithm>
#include <vector>
#include <string>
#include <set>
#include <memory>
#include <unordered_map>

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
#include "../cc-lib/threadutil.h"
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

static constexpr float DEGREES_TO_RADS =
  (1.0f / 360.0f) * 2.0f * 3.1415926535897932384626433832795f;

// Size of NES nametable
#define TILESW 32
#define TILESH 30
#define TILEST 32
static_assert(TILEST >= TILESW, "TILEST must hold TILESW");
static_assert(TILEST >= TILESW, "TILEST must hold TILESH");
static_assert(0 == (TILEST & (TILEST - 1)), "TILEST must be power of 2");

#define SPRTEXW 256
#define SPRTEXH 256
static_assert(0 == (SPRTEXW & (SPRTEXW - 1)), "SPRTEXW must be a power of 2");
static_assert(0 == (SPRTEXH & (SPRTEXH - 1)), "SPRTEXH must be a power of 2");

#define BOX_DIM 2

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

static bool draw_sprites = true;
static bool draw_boxes = true;
static bool draw_nes = true;

// XXX
static GLuint bg_texture = 0;
static GLuint sprite_texture[64] = {};

// Manages running up to X asynchronous tasks in separate threads. The
// threads are started for each Run (no thread pool), making this
// kinda high-overhead but easy to manage. It at least cleans up after
// itself.
struct Asynchronously {
  Asynchronously(int max_threads) : threads_active(0),
				    max_threads(max_threads) {
  }

  void Run(std::function<void()> f) {
    m.lock();
    if (threads_active < max_threads) {
      threads_active++;
      m.unlock();
      std::thread t{[this, f]() {
	  printf("(running asynchronously)\n");
	  f();
	  printf("(done running asynchronously)\n");
	  MutexLock ml(&this->m);
	  threads_active--;
	}};
      t.detach();
      
    } else {
      m.unlock();
      // Run synchronously.
      printf("%d threads already active, so running synchronously.\n",
	     max_threads);
      f();
    }
  }

  // Wait until all threads have finished.
  ~Asynchronously() {
    printf("Spin-wait until all threads have finished...\n");
    for (;;) {
      MutexLock ml(&m);
      if (threads_active == 0) {
	printf("... done.\n");
	return;
      }
    }
  }
    
  std::mutex m;
  int threads_active;
  const int max_threads;
};

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

static bool ParseByte(const string &s, uint8 *b) {
  if (s.size() != 2 || !Util::IsHexDigit(s[0]) || !Util::IsHexDigit(s[1]))
    return false;

  *b = Util::HexDigitValue(s[0]) * 16 + Util::HexDigitValue(s[1]);
  return true;
}

struct Tilemap {
  Tilemap() {}
  explicit Tilemap(const string &filename) {
    vector<string> lines = Util::ReadFileToLines(filename);
    for (string line : lines) {
      string key = Util::chop(line);
      if (key.empty() || key[0] == '#') continue;

      uint8 h = 0;
      if (!ParseByte(key, &h)) {
	printf("Bad key in tilemap. "
	       "Should be exactly 2 hex digits: [%s]\n", key.c_str());
	continue;
      }

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

// Again, always non-negative.
static int CCWDistance(int start_angle, int end_angle) {
  return CWDistance(end_angle, start_angle);
}

enum class ViewType {
  TOP,
  SIDE,
};

struct SM {
  std::unique_ptr<Emulator> emu;
  vector<uint8> inputs;
  Tilemap tilemap;
  
  int player_x_mem, player_y_mem;
  ViewType viewtype;
  
  uint8 ConfigByte(const map<string, string> &config, const string &key) {
    auto it = config.find(key);
    CHECK(it != config.end()) << "\nExpected " << key << " in config.";
    uint8 b;
    CHECK(ParseByte(it->second, &b)) << "Bad hex byte for " << key <<
      "in config. Should be exactly two hex digits; got [%s]\n" <<
      it->second;
    return b;
  }
  
  SM(const string &configfile) : rc("sm") {
    InitTextures();

    map<string, string> config = Util::ReadFileToMap(configfile);
    if (config.empty()) {
      fprintf(stderr, "Missing config: %s.\n", configfile.c_str());
      abort();
    }

    const string game = config["game"];
    const string tilesfile = config["tiles"];
    const string moviefile = config["movie"];
    CHECK(!game.empty());
    CHECK(!tilesfile.empty());

    player_x_mem = ConfigByte(config, "playerx");
    player_y_mem = ConfigByte(config, "playery");

    string vt = Util::lcase(config["view"]);
    if (vt == "top") viewtype = ViewType::TOP;
    else if (vt == "side") viewtype = ViewType::SIDE;
    else {
      fprintf(stderr, "No 'view' given in %s. Defaulting to TOP.",
	      configfile.c_str());
      viewtype = ViewType::TOP;
    }

    tilemap = Tilemap{tilesfile};

    emu.reset(Emulator::Create(game));
    CHECK(emu.get());

    if (!moviefile.empty()) {
      inputs = SimpleFM2::ReadInputs(moviefile);
      printf("There are %d inputs in %s.\n",
	     (int)inputs.size(), moviefile.c_str());
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

  enum SpriteType {
    BILLBOARD,
    IN_PLANE,
  };
  
  struct Sprite {
    // location of sprite -- different types will treat this
    // differently
    Vec3 loc{0.0f, 0.0f, 0.0f};
    // Pixels.
    int width = 0, height = 0;
    int texture_x = 0, texture_y = 0;
    // The texture id to use, in [0, 63].
    int texture_num = 0;
    SpriteType type = IN_PLANE;
    // Used temporarily during rendering.
    float distance = 0.0f;
  };
  
  void Loop() {
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    (void)surf;
    int frame = 0;

    int start = SDL_GetTicks();
    
    vector<uint8> start_state = emu->SaveUncompressed();

    // Just allocate the maximum size that this can ever be.
    // It's only 16MB.
    sprite_rgba.resize(64);
    for (int i = 0; i < 64; i++) {
      sprite_rgba[i].resize(SPRTEXW * SPRTEXH * 4);
    }
    
    int current_angle = 0;
    int angle_offset = 0;
    int z_offset = 0;
    int x_offset = 0;
    int y_offset = 0;
    
    bool paused = false, single_step = false;

    for (;;) {
      printf("Start loop!\n");
      emu->LoadUncompressed(start_state);

      // still alpha bug?
      // #define START_IDX 520
      // #define START_IDX 3300  // - zelda scrolling
      #define START_IDX 0
      if (START_IDX) {
	printf("SKIP to %d\n", START_IDX);
	paused = true;
	for (int z = 0; z < START_IDX; z++) {
	  emu->StepFull(inputs[z], 0);
	}
      }
      
      for (int input_idx = START_IDX; input_idx < inputs.size(); ) {
	const uint8 input = inputs[input_idx];
	frame++;

	SDL_Event event;
	if (0 != SDL_PollEvent(&event)) {
	  switch (event.type) {
	  case SDL_QUIT:
	    return;
	  case SDL_KEYUP:
	    switch (event.key.keysym.sym) {
	    case SDLK_s:
	      saving = !saving;
	      break;
	    case SDLK_LEFTBRACKET:
	      angle_offset += 15;
	      break;
	    case SDLK_RIGHTBRACKET:
	      angle_offset -= 15;
	      break;
	    case SDLK_UP:
	      z_offset++;
	      break;
	    case SDLK_DOWN:
	      z_offset--;
	      break;
	    case SDLK_LEFT:
	      x_offset--;
	      break;
	    case SDLK_RIGHT:
	      x_offset++;
	      break;
	      
	      // y offset too
	      
	    case SDLK_PERIOD:
	      single_step = true;
	      break;
	    case SDLK_b:
	      draw_boxes = !draw_boxes;
	      break;
	    case SDLK_n:
	      draw_nes = !draw_nes;
	      break;
	    case SDLK_SPACE:
	      paused = !paused;
	      printf("%s at input_idx %d.\n", paused ? "paused" : "unpaused",
		     input_idx);
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
	  
	// SDL_Delay(1000.0 / 60.0);

	if (!paused || single_step) {
	  if (single_step) {
	    printf("Frame %d\n", input_idx);
	    single_step = false;
	  }
	  emu->StepFull(input, 0);
	  input_idx++;
	}

	// printf("---\n");
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	if (draw_nes) {
	  // PERF
	  vector<uint8> image = emu->GetImageARGB();
	  BlitNESGL(image, 0, HEIGHT);
	}
	
	vector<Box> boxes = GetBoxes();

	vector<Sprite> sprites = GetSprites();

	// XXX Make optional with key
	#if 0
	int z = 240;
	for (const Sprite &s : sprites) {
	  BlitSpriteTexGL(sprite_rgba[s.texture_num], 5, z, s.height);
	  z += s.height + 5;
	}
	#endif
	
	int player_x, player_y, player_z;
	int player_angle;
	std::tie(player_x, player_y, player_z, player_angle) = GetLoc();

	player_x += x_offset;
	player_y += y_offset;
	player_z += z_offset;
	
	// XXX hack
	player_angle += angle_offset;
	while (player_angle < 0) player_angle += 360;
	while (player_angle >= 360) player_angle -= 360;
	
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
	DrawScene(boxes, sprites, player_x, player_y, player_z, current_angle);

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

    uint8 *pixels = (uint8 *)malloc(WIDTH * HEIGHT * 4);
    glReadPixels(0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    const int num = imagenum;
    imagenum++;
    asynchronously.Run([pixels, num]() {
      stbi_write_png(StringPrintf("image_%d.png", num).c_str(),
		     WIDTH, HEIGHT, 4,
		     // Start on last row.
		     pixels + (WIDTH * (HEIGHT - 1)) * 4,
		     // Negative stride to flip during saving.
		     -4 * WIDTH);
      free(pixels);
      printf("Wrote image_%d.\n", num);
    });
  }
  
  // Draw the 256x256 NES image at the specified coordinates (0,0 is
  // bottom left).
  void BlitNESGL(const vector<uint8> &image, int x, int y) {
    glPixelZoom(1.0f, -1.0f);
    (*glWindowPos2i)(x, y);
    glDrawPixels(256, 256, GL_BGRA, GL_UNSIGNED_BYTE, image.data());
  }

  void BlitSpriteTexGL(const vector<uint8> &image, int x, int y, int h) {
    glPixelZoom(1.0f, -1.0f);
    (*glWindowPos2i)(x, y);
    glDrawPixels(SPRTEXW, h, GL_RGBA, GL_UNSIGNED_BYTE, image.data());
  }

  
  vector<Sprite> GetSprites() {
    vector<Sprite> ret;

    const PPU *ppu = emu->GetFC()->ppu;

    const uint8 ppu_ctrl1 = ppu->PPU_values[0];
    const uint8 ppu_ctrl2 = ppu->PPU_values[1];
    // Are sprites 16 pixels tall?
    const bool tall_sprites = !!(ppu_ctrl1 & (1 << 5));
    const int sprite_height = tall_sprites ? 16 : 8;
    
    const bool sprites_enabled = !!(ppu_ctrl2 && (1 << 4));  
    const bool sprites_clipped = !!(ppu_ctrl2 && (1 << 2));
    
    if (!sprites_enabled) return ret;

    // Note: This is ignored if sprites are tall (and determined instead
    // from the tile's low bit).
    const bool spr_pat_high = !!(ppu_ctrl1 & (1 << 3));
    
    // Each is 0x100 bytes
    const uint8 *spram = ppu->SPRAM;
   
    // Most games use multiple sprites to draw the player and enemy,
    // since sprites are pretty small (8x8 or 8x16). For billboard
    // sprites in particular, we need to know that the sprites must
    // be drawn adjacent to one another. This is called sprite
    // fusion.
    //
    // We have to use heuristics (or maybe some sprite info file, urgh)
    // for this. We'll say that two sprites that are exactly lined
    // up (they share a complete edge) are part of the same sprite.
    // This of course may occasionally merge two sprites that shouldn't,
    // but that should at least look.. funny?
    //
    // There are 64 sprites, given by index. Since we look for exact
    // adjacency, we can find sprites using a hash table.

    struct PreSprite {
      // First pass.
      int x = 0, y = 0;
      // Union-find like algorithm. If -1, this is the terminus; otherwise,
      // it's part of the referenced fused sprite.
      int parent = -1;

      // Second pass.
      int min_x = 256, min_y = 256;
      int max_x = -1, max_y = -1;

      bool rendered = false;
    };
    vector<PreSprite> presprites{64};

    auto GetRoot = [&presprites](int a) -> int {      
      int root = a;
      while (presprites[root].parent != -1) {
	CHECK(root != presprites[root].parent);
	root = presprites[root].parent;
      }

      CHECK(presprites[root].parent == -1);
      
      // Path compression.
      while (a != root) {
	const int na = presprites[a].parent;
	// printf("Path compression %d -> %d, new root %d\n", a, na, root);
	presprites[a].parent = root;
	a = na;
      }

      return root;
    };
    
    // Union two presprite indices.
    auto Union = [&presprites, &GetRoot](int a, int b) {
      const int ra = GetRoot(a);
      const int rb = GetRoot(b);
      // For example when both arguments are the same, but
      // this also happens when we link a 2x2 square of tiles
      // back to itself. Can't create cycles!
      if (ra == rb) return;
      CHECK(presprites[rb].parent == -1)
      << rb << " -> " << presprites[rb].parent;
      CHECK(presprites[ra].parent == -1)
      << ra << " -> " << presprites[ra].parent;
      presprites[rb].parent = ra;
    };
    
    // All the presprite indices at (y * 256 + x).
    // Max 64k keys.
    unordered_map<int, vector<int>> by_coord;
    const vector<int> empty_key;
    auto Coord = [&by_coord, &empty_key](int x, int y) ->
      const vector<int> * {
      auto it = by_coord.find(y * 256 + x);
      if (it == by_coord.end()) return &empty_key;
      else return &it->second;
    };

    // PERF: Might want to exclude off-screen sprites.
    // (This is now being partially done, below)
    
    // Note: there are also flags that disable sprite rendering
    // in leftmost 8 pixels of screen. ($2001 = PPUMASK)

    for (int n = 63; n >= 0; n--) {
      const uint8 y = spram[n * 4 + 0];      
      const uint8 x = spram[n * 4 + 3];
      PreSprite &ps = presprites[n];
      ps.x = x;
      ps.y = y;
      // Look in each cardinal direction. There's a specific
      // point where an adjacent sprite would be.
      for (int up : *Coord(x, y - sprite_height)) Union(n, up);
      for (int left : *Coord(x - 8, y)) Union(n, left);
      for (int right : *Coord(x + 8, y)) Union(n, right);
      for (int down : *Coord(x, y + sprite_height)) Union(n, down);
      // XXX Maybe should consider also unioning with sprites that are
      // at this same exact coordinate. Some games draw multiple layers
      // to get more than 3 colors.

      by_coord[y * 256 + x].push_back(n);
    }

    // Now loop over all the sprite bits and complete the information
    // we need to size the fused sprites.
    for (int n = 63; n >= 0; n--) {
      const PreSprite &ps = presprites[n];
      PreSprite &rps = presprites[GetRoot(n)];
      if (ps.x > rps.max_x) rps.max_x = ps.x;
      if (ps.y > rps.max_y) rps.max_y = ps.y;
      if (ps.x < rps.min_x) rps.min_x = ps.x;
      if (ps.y < rps.min_y) rps.min_y = ps.y;
    }

    // Now, decide if we are actually rendering sprites, and prep
    // sprite memory.
    for (int n = 63; n >= 0; n--) {
      PreSprite &ps = presprites[n];
      // Sprite textures gives us a pre-allocated RGBA array for each
      // sprite number, with dimensions capable of holding any fused
      // sprite (256x256). So we can just use these. Note that there
      // may be gibberish in there already. So in this pass, clear
      // any sprites that will be used.
      if (ps.parent == -1) {
	if (ps.min_y < 240) {
	  // PERF could clear actual area needed
	  memset(sprite_rgba[n].data(), 0, sprite_rgba[n].size());
	  ps.rendered = true;
	} else {
	  ps.rendered = false;
	}
      }
    }
    
    // Remember, most of the time, sprites won't fuse. We keep looping
    // over the whole vector of sprites.
    //
    // Here, looping from 63 to 0 ensures that higher-priority sprites
    // draw on top of lower priority sprites. It's possible for sprites
    // to overlap.
    for (int n = 63; n >= 0; n--) {
      // PERF can probably avoid GetRoot since we called it for everything
      // above.
      int root_idx = GetRoot(n);
      const PreSprite &root = presprites[root_idx];
      // Off-screen fused sprite.
      if (!root.rendered) continue;

      vector<uint8> &rgba = sprite_rgba[root_idx];
      // We draw into the top-left corner of rgba.
      
      // We draw all sprite bits into the fused sprite; this applies to
      // the roots and children.
      const uint8 ypos = spram[n * 4 + 0];
      const uint8 tile_idx = spram[n * 4 + 1];
      const uint8 attr = spram[n * 4 + 2];
      const bool v_flip = !!(attr & (1 << 7));
      const bool h_flip = !!(attr & (1 << 6));
      const uint8 colorbits = attr & 3;
      const uint8 xpos = spram[n * 4 + 3];

      /*
      printf("[For %d, %d,%d to %d,%d] Draw at %d,%d tile %d %s%s\n",
	     root_idx,
	     root.min_x, root.min_y, root.max_x, root.max_y,
	     xpos, ypos, tile_idx,
	     h_flip ? "hflip " : "",
	     v_flip ? "vflip " : "");
      */
      
      const uint8 *palette_table = emu->GetFC()->ppu->PALRAM;
      
      // Draw one 8x8 sprite tile into rgba, using pattern table $0000
      // if first arg is false, $1000 if true. The tile index is the
      // index into that pattern. xdest and ydest are the screen
      // destination, which will be adjusted to place at the appropriate
      // place in the texture.
      auto OneTile = [this, v_flip, h_flip, colorbits,
		      &root, &rgba, palette_table](
			  bool patterntable_high, uint8 tile_idx,
			  int xdest, int ydest) {
	const uint32 spr_pat_addr = patterntable_high ? 0x1000 : 0x0000;
	// PERF Really need to keep computing this?
	const uint8 *vram = &emu->GetFC()->cart->
	VPage[spr_pat_addr >> 10][spr_pat_addr];

	// upper-left corner of this tile within the rgba array.
	const int x0 = xdest - root.min_x;
	const int y0 = ydest - root.min_y;
	
	const int addr = tile_idx * 16;
	for (int row = 0; row < 8; row++) {
	  const uint8 row_low = vram[addr + row];
	  const uint8 row_high = vram[addr + row + 8];

	  // bit from msb to lsb.
	  for (int bit = 0; bit < 8; bit++) {
	    const uint8 value =
	      ((row_low >> (7 - bit)) & 1) |
	      (((row_high >> (7 - bit)) & 1) << 1);

	    const int px = h_flip ? x0 + (7 - bit) : (x0 + bit);
	    const int py = v_flip ? y0 + (7 - row) : (y0 + row);

	    // XXX Might be technically possible? I think you could
	    // fuse 17 sprites and make something that was 255+16
	    // tall.
	    CHECK(px >= 0 && py >= 0 && px < SPRTEXW && py < SPRTEXH)
				     << "px: " << px << " "
				     << "py: " << py << " "
				     << "x0: " << x0 << " "
				     << "y0: " << y0 << " "
				     << "h_flip: " << h_flip << " "
				     << "v_flip: " << v_flip << " "
				     << "row: " << row << " "
				     << "bit: " << bit << " "
				     << "xdest: " << xdest << " "
				     << "ydest: " << ydest << " "
				     << "root.min_x: " << root.min_x << " "
				     << "root.min_y: " << root.min_y << " ";


	    // Clip pixels outside the 
	    // 	    if (px < 0 || py < 0 || px >= SPRTEXW || py >= SPRTEXH)
	    // continue;

	    const int pixel = (py * SPRTEXW + px) * 4;

	    // For sprites, transparent pixels need to be drawn with
	    // alpha 0. The palette doesn't matter; 0 means transparent
	    // in every palette.
	    if (value == 0) {
	      rgba[pixel + 3] = 0x00;
	    } else {
	      // Offset with palette table. Sprite palette entries come
	      // after the bg ones, so add 0x10.
	      const uint8 palette_idx = 0x10 + ((colorbits << 2) | value);
	      // ID of global NES color gamut.
	      const uint8 color_id = palette_table[palette_idx];
	      
	      // Put pixel in sprite texture:
	      rgba[pixel + 0] = ntsc_palette[color_id * 3 + 0];
	      rgba[pixel + 1] = ntsc_palette[color_id * 3 + 1];
	      rgba[pixel + 2] = ntsc_palette[color_id * 3 + 2];
	      rgba[pixel + 3] = 0xFF;
	    }
	  }
	}
      };
      
      if (tall_sprites) {
	// Odd and even tile numbers are treated differently.
	if ((tile_idx & 1) == 0) {
	  // This page:
	  // http://noelberry.ca/nes
	  // verifies that tiles t and t+1 are drawn top then bottom.
	  if (v_flip) {
	    // in y-flip scenarios, we have to flip the
	    // y positions here so that the whole 8x16 sprite is flipping,
	    // rather than its two 8x8 components. So tile_idx actually goes
	    // on bottom.
	    OneTile(false, tile_idx, xpos, ypos + 8);
	    OneTile(false, tile_idx + 1, xpos, ypos);
	  } else {
	    OneTile(false, tile_idx, xpos, ypos);
	    OneTile(false, tile_idx + 1, xpos, ypos + 8);
	  }
	} else {
	  // this does happen in zelda! (during scroll?)
	  printf("odd tile %d!?\n", tile_idx);
	  // CHECK(false);
	  
	  // XXX I assume this drops the low bit? I don't see that
	  // documented but it wouldn't really make sense otherwise
	  // (unless tile 255 wraps to 0?)
	  if (v_flip) {
	    OneTile(true, tile_idx - 1, xpos, ypos + 8);
	    OneTile(true, tile_idx, xpos, ypos);
	  } else {
	    OneTile(true, tile_idx - 1, xpos, ypos);
	    OneTile(true, tile_idx, xpos, ypos + 8);
	  }
	}
      } else {
	// this is much easier but not used in zelda
	// (I think it's needed for mario though)
	OneTile(spr_pat_high, tile_idx, xpos, ypos);
      }
    }

    // The sprite image and fusion and all that are independent of the
    // scroll (which only affects the background). But we need to move
    // their position in space using (only) the fine_scroll, since we
    // mod out by this in the calculation of the background boxes.
    int coarse_scroll, fine_scroll;
    std::tie(coarse_scroll, fine_scroll) = XScroll();
    
    // OK, now all of the root sprites have their fused data drawn at 0,0
    // and we also know how big they are and where they are in screen
    // coordinates. One more pass, only looking at the root sprites.
    // We copy them to the corresponding sprite textures for GL, and
    // output the Sprite objects so that the render phase knows where
    // to draw them.
    //
    // At this point the order of the sprites shouldn't matter; we've already
    // drawn these into the rgba vectors. The rendering code may need to
    // sort them by their physical position in order to get alpha to be correct.
    for (int n = 63; n >= 0; n--) {
      const PreSprite &ps = presprites[n];
      if (ps.rendered && ps.parent == -1) {

	// Copy sprite texture to GL texture.
	glBindTexture(GL_TEXTURE_2D, sprite_texture[n]);
	// PERF: Can just copy the appropriate sub-region, but we
	// need to deal with the fact that GL coordinates are upside-down.
	//
	// RECALL that max_x and max_y are the max coordinates of the top-left
	// corners, so they need +8 and +sprite_height.
	glTexSubImage2D(GL_TEXTURE_2D, 0,
			0, 0, SPRTEXW, SPRTEXH,
			GL_RGBA, GL_UNSIGNED_BYTE,
			sprite_rgba[n].data());

	// TODO: Decide on BILLBOARD vs IN_PLANE etc. Probably
	// should not merge sprites of different types.
	Sprite s;
	const int height_px = (ps.max_y + sprite_height) - ps.min_y;
	const int width_px = (ps.max_x + 8) - ps.min_x;
	if (true) {
	  s.type = BILLBOARD;
	  
	  // Use centroid of fused sprite.
	  float cx = ((ps.max_x + 8) + ps.min_x) * 0.5f + fine_scroll;
	  float cy = ((ps.max_y + sprite_height) + ps.min_y) * 0.5f;

	  switch (viewtype) {
	  case ViewType::TOP:
	    // These are in tile space, not pixel space.
	    s.loc.x = cx / 8.0f;
	    s.loc.y = cy / 8.0f;
	    // XXX bottom should always be on the floor, yeah?
	    s.loc.z = 0.5 * (height_px / 8.0f);
	    break;
	  case ViewType::SIDE:
	    // Left side of sprite should always be on the left wall?
	    s.loc.x = 0.5 * (width_px / 8.0f);
	    // XXX don't know why we need -16 and -8 here, but it
	    // makes them line up.
	    s.loc.y = (cx - 16) / 8.0f;
	    s.loc.z = (255 - cy - 8) / 8.0f;
	    break;
	  }

	} else {
	  s.type = IN_PLANE;
	  // XXX support IN_PLANE for SIDE sprites.

	  s.loc.x = (ps.min_x + fine_scroll) / 8.0f;
	  s.loc.y = ps.min_y / 8.0f;
	  s.loc.z = 0.01f;
	}

	s.texture_num = n;
	s.width = (ps.max_x + 8) - ps.min_x;
	s.height = (ps.max_y + sprite_height) - ps.min_y;
	s.texture_x = 0;
	s.texture_y = 0;

	ret.push_back(s);
      }
    }
    
    return ret;
  }
 
  // All boxes are 1x1x1. This returns their "top-left" corners.
  // Larger Z is "up".
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
    PPU *ppu = emu->GetFC()->ppu;
    const uint8 *nametable = ppu->NTARAM;
    const uint8 *palette_table = ppu->PALRAM;
    const uint8 ppu_ctrl1 = ppu->PPU_values[0];
   
    // BG pattern table can be at 0 or 0x1000, depending on control bit.
    const uint32 bg_pat_addr = (ppu_ctrl1 & (1 << 4)) ? 0x1000 : 0x0000;
    const uint8 *vram = &emu->GetFC()->cart->
      VPage[bg_pat_addr >> 10][bg_pat_addr];

    // The actual BG image, used as a texture for the blocks.
    vector<uint8> bg;
    // Don't bother reserving TILEST size; we'll just copy the portion
    // that might change into the larger texture. (The texture has to
    // have power-of-two dimensions, but not the copied area.)
    bg.resize(TILESW * TILESH * 8 * 8 * 4);

    // Read the tile for the wide tile coordinates (x,y). x may range
    // from 0 to TILESW*2 - 1.
    auto WideNametable = [nametable](int x, int y) -> uint8 {
      static_assert(TILESW == 32, "assumed here.");
      if (x & 32) {
	return nametable[0x400 + y * TILESW + (x & 31)];
      } else {
	return nametable[y * TILESW + x];
      }
    };

    // Read the two attribute (color) bits for the wide tile coordinates
    // x,y, as above.
    auto WideAttribute = [nametable](int x_orig, int y) -> uint8 {
      const uint32 tableoffset = (x_orig & 32) ? 0x400 : 0x0;
      // Attribute byte starts right after tiles in the nametable.
      // First need to figure out which byte it is, based on which
      // square (4x4 tiles).
      const int x = x_orig & 31;
      const int square_x = x >> 2;
      const int square_y = y >> 2;
      const uint8 attrbyte =
	  nametable[
	      // select nametable
	      tableoffset +
	      // skip over tiles to attribute table
	      TILESW * TILESH +
	      // index within attributes
	      (square_y * (TILESW >> 2)) + square_x];
      // Now get the two bits out of it.
      const int sub_x = (x >> 1) & 1;
      const int sub_y = (y >> 1) & 1;
      const int shift = (sub_y * 2 + sub_x) * 2;

      return (attrbyte >> shift) & 3;
    };

    int coarse_scroll, fine_scroll;
    std::tie(coarse_scroll, fine_scroll) = XScroll();
    
    for (int ty = 0; ty < TILESH; ty++) {
      for (int tx = 0; tx < TILESW; tx++) {
	// tx,ty is the tile offset within the output screen, always
	// taking on values of [0,TILESW) and [0,TILESH). To implement
	// scrolling, we need to know the input tile indices to read
	// from the nametable.
	//
	// We only support x scrolling for now, so this is just ty.
	const int srcty = ty;
	const int srctx = (tx + (coarse_scroll >> 3)) % (TILESW * 2);
	CHECK(srctx >= 0 && srctx < TILESW * 2)
	  << tx << " " << coarse_scroll << " " << srctx;

	// nametable[srcty * TILESW + tx];
	const uint8 tile = WideNametable(srctx, srcty);
	
	// Draw to BG.

	// Selects the color palette.
	const uint8 attr = WideAttribute(srctx, srcty);

	// Each tile is made of 8 bytes giving its low color bits, then
	// 8 bytes giving its high color bits.
	const int addr = tile * 16;

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
	    // Normally we would take into account the fine x scroll
	    // (xoffset) here, but we're not trying to actually draw
	    // the game's screen---we want everything to be tile-aligned.
	    // Instead, we'll move the camera and sprites by the fine
	    // amount.
	    
	    const int px = tx * 8 + bit;
	    const int py = ty * 8 + row;
	    const int pixel = (py * TILESW * 8 + px) * 4;
	    bg[pixel + 0] = ntsc_palette[color_id * 3 + 0];
	    bg[pixel + 1] = ntsc_palette[color_id * 3 + 1];
	    bg[pixel + 2] = ntsc_palette[color_id * 3 + 2];
	    bg[pixel + 3] = 0xFF;
	  }
	}
      }
    }


    // Loop over every 4x4 block.
    static_assert(BOX_DIM == 2, "This is hard-coded here.");
    for (int ty = 0; ty < TILESH; ty += 2) {
      for (int tx = 0; tx < TILESW; tx += 2) {
	// Take (x) scrolling into account.
	const int srcty = ty;
	const int srctx = (tx + (coarse_scroll >> 3)) % (TILESW * 2);

	CHECK(!(srcty & 1)) << srcty;
	// Here we want to loop over all four tiles inside this
	// block. But membership in a block is not influenced
        // by the scroll, so this only works for even coarse_scroll.
	CHECK(!(srctx & 1)) << srctx << " " << coarse_scroll << " " << tx;
	
	TileType result = UNMAPPED;
	for (int by = 0; by < 2; by++) {
	  for (int bx = 0; bx < 2; bx++) {
	    const uint8 tile = WideNametable(srctx + bx, srcty + by);
	    const TileType type = tilemap.data[tile];

	    auto Max = [](const TileType &a, const TileType &b) {
	      if (a == WALL || b == WALL) return WALL;
	      else if (a == FLOOR || b == FLOOR) return FLOOR;
	      else if (a == RUT || b == RUT) return RUT;
	      return UNMAPPED;
	    };
	    
	    result = Max(result, type);
	  }
	}

	// Boxes have size--position them so that the face we want
	// to see is at the depth we want. For a floor, for example,
	// this is not 0.0 but 0.0 - BOX_DIM, since we want the top
	// of the box to be at 0.0, not its bottom.

	float d = 0.0f;
	if (result == WALL) {
	  d = 2.0f - BOX_DIM;
	} else if (result == FLOOR) {
	  d = 0.0f - BOX_DIM;
	  // continue;
	} else if (result == RUT) {
	  d = -0.50f - BOX_DIM;
	} else if (result == UNMAPPED) {
	  d = 4.0f - BOX_DIM;
	}

	switch (viewtype) {
	case ViewType::TOP:
	  // "Forward" is the screen y axis, "Down" is 
	  ret.push_back(Box{Vec3{(float)tx, (float)ty, d}, BOX_DIM, tx, ty});
	  break;
	case ViewType::SIDE:
	  // depth is to the right (floor, a depth of 0.0, is the left wall).
	  // but since blocks have XXX HERE.
	  // "Forward" is the screen x axis, "Down" is the screen y axis,
	  // and depth is to the right (floor, a depth of 0.0, is the
	  // left wall).
	  ret.push_back(Box{Vec3{
		-d, (float)tx, (float)(TILESH - 1 - ty)},
		BOX_DIM, tx, ty});
	  break;
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
		 const vector<Sprite> &orig_sprites,
		 int player_x, int player_y, int player_z,
		 int player_angle) {

    /// XXX HERE: Use z coordinate; try to remove hacks or insert
    // parallel hacks for SIDE.
    // Put player in GL coordinates.
    // z is 3/4 of a 4x4 block height
    const Vec3 player{player_x / 8.0f,
	((TILESH * 8 - 1) - player_y) / 8.0f,
	player_z / 8.0f + 1.5f
	// 3.0f
	};

    // Put boxes in GL space where Y=0 is bottom-left, not top-left.
    // This also conceptually changes the origin of the box itself. In
    // this function, 0,0,0 is the "bottom front left" of the box.
    vector<Box> boxes;
    boxes.reserve(orig_boxes.size());
    for (const Box &box : orig_boxes) {
      boxes.push_back(
	  Box{Vec3{box.loc.x, (float)(TILESH - 1) - box.loc.y, box.loc.z},
	      box.dim,
		box.texture_x, box.texture_y});
    }

    // Flip the y location of sprites.
    vector<Sprite> sprites;
    sprites.reserve(orig_sprites.size());
    for (const Sprite &sprite : orig_sprites) {
      Sprite s = sprite;
      s.loc.y = (float)(TILESH - 1) - s.loc.y;
      s.distance = Vec3Distance(s.loc, player);
      sprites.push_back(s);
    }

    std::sort(sprites.begin(), sprites.end(),
	      [](const Sprite &a, const Sprite &b) {
		return b.distance - a.distance;
	      });
    
    // printf("There are %d boxes.\n", (int)boxes.size());
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    // Put player on ground with top of screen straight ahead.
    glRotatef(-90.0f, 1.0, 0.0, 0.0);

    // Rotate according to the direction the player is facing.
    glRotatef(player_angle, 0.0, 0.0, 1.0);
    
    // Move "camera".
    glTranslatef(-player.x, -player.y, -player.z);
    // XXX don't need this
#if 1
    glBegin(GL_LINE_STRIP);
    glVertex3f(0.0f, 0.0f, 0.0f);
    glVertex3f((float)TILESW, 0.0f, 0.0f);
    glVertex3f((float)TILESW, (float)TILESH, 0.0f);
    glVertex3f(0.0f, (float)TILESH, 0.0f);
    glVertex3f(0.0f, 0.0f, 0.0f);
    glEnd();
#endif

    glEnable(GL_TEXTURE_2D);
    // glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
    // GL_MODULATE is needed for alpha blending, not sure why.
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
   
    if (draw_boxes) {
      glDisable(GL_BLEND);

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

	// printf("Draw box at %f,%f,%f\n", box.loc.x, box.loc.y, box.loc.z);
      
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
	auto CCWFace = [tx, ty, tt](const Vec3 &a, const Vec3 &b,
				    const Vec3 &c, const Vec3 &d) {
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
    }

    // Now sprites.
    if (draw_sprites) {

      glEnable(GL_BLEND);
      // Should only be 1.0 or 0.0.
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

      for (const Sprite &sprite : sprites) {
	glBindTexture(GL_TEXTURE_2D, sprite_texture[sprite.texture_num]);
	glBegin(GL_TRIANGLES);
	
	const float tx = sprite.texture_x / (float)SPRTEXW;
	const float ty = sprite.texture_y / (float)SPRTEXH;

	const float tw = (sprite.width - sprite.texture_x) / (float)SPRTEXW;
	const float th = (sprite.height - sprite.texture_y) / (float)SPRTEXH;

	// Give bottom left first, and go clockwise.
	auto CCWFace = [tx, ty, tw, th](const Vec3 &a, const Vec3 &b,
					const Vec3 &c, const Vec3 &d) {
	  //  (0,0) (1,0)
	  //    d----c
	  //    | 1 /|
	  //    |  / |
	  //    | /  |
	  //    |/ 2 |
	  //    a----b
	  //  (0,1)  (1,1)  texture coordinates

	  glTexCoord2f(tx,      ty + th); glVertex3fv(a.Floats());
	  glTexCoord2f(tx + tw, ty);      glVertex3fv(c.Floats());
	  glTexCoord2f(tx,      ty);      glVertex3fv(d.Floats());

	  glTexCoord2f(tx,      ty + th); glVertex3fv(a.Floats());
	  glTexCoord2f(tx + tw, ty + th); glVertex3fv(b.Floats());
	  glTexCoord2f(tx + tw, ty);      glVertex3fv(c.Floats());
	};

	if (sprite.type == IN_PLANE) {
	  const float wf = sprite.width / 8.0f;
	  const float hf = sprite.height / 8.0f;

	  Vec3 a = sprite.loc;
	  Vec3 b = Vec3Plus(a, Vec3{wf, 0.0f, 0.0f});
	  Vec3 c = Vec3Plus(a, Vec3{wf, hf, 0.0f});
	  Vec3 d = Vec3Plus(a, Vec3{0.0f, hf, 0.0f});
	  CCWFace(a, b, c, d);

	} else {
	  CHECK(sprite.type == BILLBOARD);
	  /*
	  printf("Draw billboard tex=%d at %.2f,%.2f,%.2f %dx%d\n",
		 sprite.texture_num, sprite.loc.x, sprite.loc.y, sprite.loc.z,
		 sprite.width, sprite.height);
	  */

	  // Compute transform for this billboard. We can do this manually
	  // pretty easy.

	  // We're rotating the billboard around the z axis through its
	  // center point,
	  //
 	  //    -----*-----
	  //
	  //  (top down view)

	  const float player_rads = -player_angle * DEGREES_TO_RADS;
	  // printf("p angle: d = %.2f rads\n", player_angle, player_rads);
	  
	  // half-width and half-height from center point.
	  const float hwf = 0.5f * (sprite.width / 8.0f);
	  const float hhf = 0.5f * (sprite.height / 8.0f);
	  // We're rotating the plane within a cylinder.
	  // looking straight down on the billboard, this is just
	  // a rotation of a line segment within a circle.
	  // Angle of 0 should give hyf=0 and hxf=hwf.
	  const float hxf = cosf(player_rads) * hwf;
	  const float hyf = sinf(player_rads) * hwf;
	  
	  const Vec3 &ctr = sprite.loc;
	  Vec3 a = Vec3Plus(ctr, Vec3{-hxf, -hyf, -hhf});
	  Vec3 b = Vec3Plus(ctr, Vec3{+hxf, +hyf, -hhf});
	  Vec3 c = Vec3Plus(ctr, Vec3{+hxf, +hyf, +hhf});
	  Vec3 d = Vec3Plus(ctr, Vec3{-hxf, -hyf, +hhf});
	  CCWFace(a, b, c, d);

	}
	glEnd();
      }
    }
    // printf("---\n");
    
    
    glDisable(GL_TEXTURE_2D);
  }

  // Get the current X Scroll as a coarse and fine component.
  // Both are in pixels so that coarse+fine is the actual scroll
  // amount, but coarse is mod 16 (two tiles) so that we can
  // work with 2x2 blocks. (If we don't do this, odd amounts of
  // scroll tiles causes texture misalignment.)
  std::pair<int, int> XScroll() {
    const PPU *ppu = emu->GetFC()->ppu;
    const uint8 ppu_ctrl1 = ppu->PPU_values[0];
    const uint32 tmp = ppu->GetTempAddr();
    const uint8 xoffset = ppu->GetXOffset();
    const uint8 xtable_select = !!(ppu_ctrl1 & 1);
    
    // Combine coarse and fine x scroll
    uint32 xscroll = (xtable_select << 8) | ((tmp & 31) << 3) | xoffset;

    // printf("Scroll x: %d, tmp: %u, table: %u, together: %u\n",
    // (int)xoffset, tmp, xtable_select, xscroll);

    // Scroll in two-tile increments.
    int coarse_scroll = xscroll & ~15;
    int fine_scroll = xscroll & 15;
    return { coarse_scroll, fine_scroll };
  }

  // x, y, z, angle (deg, where 0 is north)
  std::tuple<int, int, int, int> GetLoc() {
    vector<uint8> ram = emu->GetMemory();
    
    // Link's top-left corner, so add 8,8 to get center.
    uint8 sx = ram[player_x_mem] + 8, sy = ram[player_y_mem] + 8;

    // Take x scroll into account.
    int coarse_scroll, fine_scroll;
    std::tie(coarse_scroll, fine_scroll) = XScroll();
    sx += fine_scroll;

    // XXX need some way of getting angle for mario
    const uint8 dir = ram[0x98];
    int angle = 0;
    switch (dir) {
    case 1: angle = 90; break;  // East
    case 2: angle = 270; break; // West
    case 4: angle = 180; break; // South
    case 8: angle = 0; break;   // North
    default:;
    }

    switch (viewtype) {
    default:
    case ViewType::TOP:
      return make_tuple(sx, sy, 0, angle);
    case ViewType::SIDE:
      return make_tuple(0, sx, sy, angle);    
    }
  }

  void InitTextures() {
    // Allocate one bg texture.
    {
      glGenTextures(1, &bg_texture);
      glBindTexture(GL_TEXTURE_2D, bg_texture);
      vector<uint8> bg;
      bg.resize(8 * 8 * TILEST * TILEST * 4);
      // PERF is RGBA a good choice? It aligns better but does it make
      // blitting much more costly because of the (unused) alpha channel?
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, TILEST * 8, TILEST * 8, 0,
		   GL_RGBA, GL_UNSIGNED_BYTE, bg.data());
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

      // No good answer here. Just make sure to hit pixels exactly.
      // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }

    // Kinda wasteful, but allocate one "huge" fused sprite texture (256x256,
    // which is as big as it could be) for each sprite slot. No way to use
    // all of this at once, but it makes it much simpler to allocate and
    // avoids having to do run-time packing.
    {
      glGenTextures(64, sprite_texture);
      // For initialization, use the same array. Do we even need to initialize?
      vector<uint8> spr;
      for (int i = 0; i < SPRTEXW * SPRTEXH; i++) {
	// Make uninitialized data shine.
	spr.push_back(rc.Byte());
	spr.push_back(rc.Byte());
	spr.push_back(rc.Byte());
	spr.push_back(0xAA);
      }
      // spr.resize(SPRTEXW * SPRTEXH * 4);

      for (int i = 0; i < 64; i++) {
	glBindTexture(GL_TEXTURE_2D, sprite_texture[i]);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, SPRTEXW, SPRTEXH, 0,
		     GL_RGBA, GL_UNSIGNED_BYTE, spr.data());
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	// XXX Should clamp textures.
      }
    }
  }
  
 private:
  Asynchronously asynchronously{12};
  vector<vector<uint8>> sprite_rgba;
  ArcFour rc;
  NOT_COPYABLE(SM);
};

// Same as gluPerspective, but without depending on GLU.
static void PerspectiveGL(double fovY, double aspect,
			  double zNear, double zFar) {
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

  // Lock to vsync rate.
  SDL_GL_SetAttribute(SDL_GL_SWAP_CONTROL, 1);
  
  // Can use SDL_FULLSCREEN here for full screen immersive
  // 8 bit action!!
  CHECK(SDL_SetVideoMode(WIDTH, HEIGHT, bpp,
			 SDL_OPENGL)) << SDL_GetError();

  InitGL();

  string configfile = argc > 1 ? argv[1] : "zelda.config";
  
  {
    SM sm{configfile};
    sm.Play();
  }

  SDL_Quit();
  return 0;
}
