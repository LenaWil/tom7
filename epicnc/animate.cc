
#include <vector>
#include <utility>
#include <tuple>
#include <cstdint>

#include "SDL.h"
#include "sdl/sdlutil.h"
#include "math.h"

#include "point.h"
#include "inversion.h"
#include "base/stringprintf.h"

using namespace std;

using uint32 = uint32_t;
using uint64 = uint64_t;
using uint16 = uint16_t;
using uint8 = uint8_t;
using int64 = int64_t;
using int32 = int32_t;

// We use these interchangeably; ensure that they are consistent.
// The S* and U* versions come from SDL, the simple ones from base.h.
// (TODO: Is there a way to check that the types are literally
// the same?)
static_assert(sizeof(Sint64) == sizeof(int64), "int 64");
static_assert(sizeof(Uint64) == sizeof(uint64), "uint 64");
static_assert(sizeof(Sint32) == sizeof(int32), "int 32");
static_assert(sizeof(Uint32) == sizeof(uint32), "uint 32");
static_assert(sizeof(Uint16) == sizeof(uint16), "uint 16");
static_assert(sizeof(Uint8) == sizeof(uint8), "uint 8");

#define PI 3.14159265358979323846264338327950288419716939937510
#define TWOPI (2.0 * PI) // 6.28318530718


#define STARTW 1920
#define STARTH 1080

// TODO: Make into little library. Make constexpr mixcolor that's
// correct for the platform.
static constexpr uint32 RGBA(uint8 r, uint8 g, uint8 b, uint8 a) {
  return (a << 24) |
    (b << 16) |
    (g << 8) |
    r;
}
static constexpr uint32 RED = RGBA(0xFF, 0x0, 0x0, 0xFF);
static constexpr uint32 BLACK = RGBA(0x0, 0x0, 0x0, 0xFF);
static constexpr uint32 WHITE = RGBA(0xFF, 0xFF, 0xFF, 0xFF);
static constexpr uint32 GREEN = RGBA(0x0, 0xFF, 0x0, 0xFF);
static constexpr uint32 BLUE = RGBA(0x0, 0x0, 0xFF, 0xFF);
static constexpr uint32 BACKGROUND = RGBA(0x00, 0x20, 0x00, 0xFF);

// XXX whither?
static SDL_Surface *screen;

string ptos(Pt p) {
  return StringPrintf("(%.4f, %.4f)", p.x, p.y);
}

int main(int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY,
                      SDL_DEFAULT_REPEAT_INTERVAL);

  SDL_EnableUNICODE(1);
  screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, BACKGROUND);
  SDL_Flip(screen);

  // All angles in radians, distances in "units".

  // Diameter of big base gear.
  double sun_dia = 6.0;
  // Diameter of big nested gear.
  double earth_dia = 3.9;
  // Center of earth to center of sun.
  double orbit = 2.413;
  // Distance from earth's center to its wand's tip.
  double wand_length = orbit;

  // XXX make accurate
  double earth_gear_ratio = 4.0;
  const double earthdriver_dia = earth_dia / earth_gear_ratio;

  // Externally driven. Sun is actually driven by a little gear,
  // but we can pretend it's driven directly. The earth's driver
  // has an interaction with the sun, however.
  //
  // Both in mechanism-space.
  double sun_angle = 0.0;
  double earthdriver_angle = 0.0;

  struct Configuration {
    double earth_x = 0.0, earth_y = 0.0;
    double earth_angle = 0.0;
    double wand_x = 0.0, wand_y = 0.0;
  };

  auto Compute = [sun_dia, earth_dia, orbit, wand_length,
                  earth_gear_ratio, earthdriver_dia]
    (double sun_a, double ed_a) -> Configuration {

    Configuration c;

    // Earth's center.
    c.earth_x = sin(sun_a) * orbit;
    c.earth_y = cos(sun_a) * orbit;

    // The earth driver and earth would be in a normal gearing
    // relationship, but the earth orbits the earth driver as well
    // (because it is on the sun), causing a kind of phantom rotation.
    const double effective_angle = ed_a - sun_a;

    c.earth_angle = effective_angle / -earth_gear_ratio;

    c.wand_x = sin(c.earth_angle) * wand_length + c.earth_x;
    c.wand_y = cos(c.earth_angle) * wand_length + c.earth_y;

    return c;
  };

  const double max_radius = wand_length + orbit;

  auto ComputeFn = [Compute, earth_gear_ratio, max_radius](Pt in) -> Pt {
    Configuration c = Compute(in.x * TWOPI,
			      in.y * earth_gear_ratio * TWOPI);

    return Pt{((c.wand_x / max_radius) + 1.0) * 0.5,
              ((c.wand_y / max_radius) + 1.0) * 0.5};
  };

  // PERF We currently aren't using the table.
  Inversion<decltype(ComputeFn)> inv{
    ComputeFn, 200, (int)(earth_gear_ratio * 200), 900, 900};

  static constexpr int ORIGIN_X = STARTW >> 1;
  static constexpr int ORIGIN_Y = STARTH >> 1;
  static constexpr double PIXELS_PER_UNIT = STARTH / 12.0;
  static constexpr double UNITS_PER_PIXEL = 12.0 / STARTH;

  auto ToScreen = [](double x, double y) {
    return make_pair(x * PIXELS_PER_UNIT + ORIGIN_X,
                     y * PIXELS_PER_UNIT + ORIGIN_Y);
  };

  auto ToMechanism = [](int x, int y) -> Pt {
    return Pt{(x - ORIGIN_X) * UNITS_PER_PIXEL,
	      (y - ORIGIN_Y) * UNITS_PER_PIXEL};
  };

  // All of these draw functions take mechanism-space coordinates.
  auto DrawLine = [&ToScreen](double x0, double y0, double x1, double y1,
                              uint32 color = WHITE) {
    int sx0, sy0, sx1, sy1;
    std::tie(sx0, sy0) = ToScreen(x0, y0);
    std::tie(sx1, sy1) = ToScreen(x1, y1);
    sdlutil::drawclipline(screen, sx0, sy0, sx1, sy1,
                          (color >> 24) & 255,
                          (color >> 16) & 255,
                          (color >> 8) & 255);
  };

  auto DrawThickLine = [&ToScreen](double x0, double y0, double x1, double y1,
				   uint32 color = WHITE) {
    int sx0, sy0, sx1, sy1;
    std::tie(sx0, sy0) = ToScreen(x0, y0);
    std::tie(sx1, sy1) = ToScreen(x1, y1);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
	sdlutil::drawclipline(screen, sx0 + dx, sy0 + dy, sx1 + dx, sy1 + dy,
			      (color >> 24) & 255,
			      (color >> 16) & 255,
			      (color >> 8) & 255);
      }
    }
  };


  auto DrawGear = [&DrawLine](double cx, double cy, double radius,
                              double angle, int sides) {
    double radians_per_edge = TWOPI / (double)sides;

    double x = sin(angle) * radius + cx;
    double y = cos(angle) * radius + cy;
    for (int i = 1; i <= sides; i++) {
      double xx = sin(angle + radians_per_edge * i) * radius + cx;
      double yy = cos(angle + radians_per_edge * i) * radius + cy;

      DrawLine(x, y, xx, yy, WHITE);
      x = xx;
      y = yy;
    }
  };

  auto DrawPoint = [&DrawLine](double x, double y) {
    DrawLine(x, y, x, y);
  };

  Pt prev{0.0, 0.0};
  vector<pair<Pt, Pt>> path;

  auto ScreenToNorm = [&ToMechanism, max_radius](int x, int y) -> Pt {
    // In mechanism space.
    const Pt mech = ToMechanism(x, y);

    // And in 0-1.
    return Pt{((mech.x / max_radius) + 1.0) * 0.5,
  	      ((mech.y / max_radius) + 1.0) * 0.5};
  };

  int tt = 0;
  auto Draw = [&sun_angle,
               &earthdriver_dia, &earthdriver_angle,
               &sun_dia, &earth_dia, &earth_gear_ratio,
               &wand_length, &orbit,
               &prev, &path,
               &Compute, &tt,
	       &ScreenToNorm, &inv,
               &DrawGear, &DrawPoint, &DrawLine, &DrawThickLine]() {
    sdlutil::clearsurface(screen, BACKGROUND);

#if 0
    Pt prev;
    for (int y = 0; y < STARTH; y++) {
      for (int x = 0; x < STARTW; x++) {
	Pt out = ScreenToNorm(x, y);
	if (inv.Invert2(prev, out, &prev)) {
	  sdlutil::drawpixel(screen, x, y, 0, 200, 0);
	}
      }
    }
#endif

#if 0
    // Draws mapping.
    const double max_radius = wand_length + orbit;

    static constexpr int SIZE = 800;
    static constexpr int YOFF = (STARTH - SIZE) >> 1;
    for (int y = 0; y < SIZE; y++) {
      double sa = y * (TWOPI / SIZE);
      const uint8 b = 255 * (y / (double)SIZE);
      for (int x = 0; x < SIZE; x++) {
        if ((x - y) == tt) {
          double ea = x * (TWOPI * earth_gear_ratio / SIZE);
          const uint8 r = 255 * (x / (double)SIZE);
          sdlutil::drawpixel(screen, x, YOFF + y, r, 128, b);

          Configuration c = Compute(sa, ea);

          int cx = ((c.wand_x / max_radius) + 1.0) * 0.5 * SIZE;
          int cy = ((c.wand_y / max_radius) + 1.0) * 0.5 * SIZE;
          sdlutil::drawpixel(screen, cx + SIZE + 20, YOFF + cy, r, 128, b);
        }

      }

    }

    tt++;
    tt %= SIZE;
#endif

    // Draw path.
    for (const auto p : path) {
      DrawThickLine(p.first.x, p.first.y, p.second.x, p.second.y, BLUE);
    }

    Configuration c = Compute(sun_angle, earthdriver_angle);

    // Sun just depends on its angle.
    DrawGear(0, 0, sun_dia / 2.0, sun_angle, 22);
    // Same.
    DrawGear(0, 0, earthdriver_dia / 2.0, earthdriver_angle, 5);

    DrawPoint(c.earth_x, c.earth_y);

    DrawGear(c.earth_x, c.earth_y, earth_dia / 2, c.earth_angle, 20);

    // Draw the wand.
    DrawLine(c.earth_x, c.earth_y, c.wand_x, c.wand_y, GREEN);
  };

  bool sun_on = true, earth_on = true;
  double t = 0.0;
  while(1) {
    SDL_Event event;
    /* event loop */
    while (SDL_PollEvent(&event)) {
      switch(event.type) {
      case SDL_QUIT:
        return 0;

      case SDL_MOUSEBUTTONDOWN: {
	SDL_MouseButtonEvent *e = (SDL_MouseButtonEvent*)&event;
	if (e->button == SDL_BUTTON_RIGHT) {
	  int mousex = e->x;
	  int mousey = e->y;

	  Pt output = ScreenToNorm(mousex, mousey);

	  printf("mouse %d %d norm %f %f\n",
		 mousex, mousey,
		 output.x, output.y);

	  Configuration cur = Compute(sun_angle, earthdriver_angle);

	  vector<Pt> solve_path;
	  Pt input;
	  if (inv.Invert2({sun_angle / TWOPI, 
	  	           earthdriver_angle / (earth_gear_ratio * TWOPI)}, 
	                  output, &input, &solve_path)) {
	    // printf("%s <- %s\n", ptos(output).c_str(),
	    // ptos(input).c_str());

	    printf("Path size %d\n", solve_path.size());
	    for (Pt point : solve_path) {
	      sun_angle = point.x * TWOPI;
	      earthdriver_angle = point.y * earth_gear_ratio * TWOPI;

	      Draw();

	      SDL_Flip(screen);
	      SDL_Delay(10);
	    }

	    sun_angle = input.x * TWOPI;
	    earthdriver_angle = input.y * earth_gear_ratio * TWOPI;

	  } else {
	    printf("Cannot get to %s\n", ptos(output).c_str());
	  }

	}
      }

      case SDL_MOUSEMOTION: {
	SDL_MouseMotionEvent *e = (SDL_MouseMotionEvent*)&event;
	int mousex = e->x;
	int mousey = e->y;

	Pt output = ScreenToNorm(mousex, mousey);

	/*
	printf("mouse %d %d norm %f %f\n",
	       mousex, mousey,
	       output.x, output.y);
	*/

	Configuration cur = Compute(sun_angle, earthdriver_angle);

	vector<Pt> solve_path;
	Pt input;
	if (inv.Invert2({sun_angle / TWOPI, 
		         earthdriver_angle / (earth_gear_ratio * TWOPI)}, 
	                output, &input, nullptr)) {
	  // printf("%s <- %s\n", ptos(output).c_str(),
	  // ptos(input).c_str());
	  #if 0
	  printf("Path size %d\n", solve_path.size());
	  for (Pt point : solve_path) {
	    sun_angle = point.x * TWOPI;
	    earthdriver_angle = point.y * earth_gear_ratio * TWOPI;

	    /*
	    if (e->state & SDL_BUTTON_LMASK) {
	      Configuration updated = Compute(sun_angle, earthdriver_angle);
	      path.emplace_back(Pt{cur.wand_x, cur.wand_y},
				Pt{updated.wand_x, updated.wand_y});
	    }
	    */
	    Draw();
	   
	    SDL_Flip(screen);
	    SDL_Delay(10);
	  }
	  #endif

	  sun_angle = input.x * TWOPI;
	  earthdriver_angle = input.y * earth_gear_ratio * TWOPI;

	  if (e->state & SDL_BUTTON_LMASK) {
	    Configuration updated = Compute(sun_angle, earthdriver_angle);
	    path.emplace_back(Pt{cur.wand_x, cur.wand_y},
			      Pt{updated.wand_x, updated.wand_y});
	  }

	} else {
	  printf("%s unreachable!\n", ptos(output).c_str());
	}
      }

      case SDL_KEYDOWN: {
        int key = event.key.keysym.sym;
        switch(key) {
        case SDLK_s:
          sun_on = !sun_on;
          break;
        case SDLK_e:
          earth_on = !earth_on;
          break;
        case SDLK_z:
          sun_angle -= 0.01;
          break;
        case SDLK_x:
          sun_angle += 0.01;
          break;
        case SDLK_COMMA:
          earthdriver_angle -= 0.01;
          break;
        case SDLK_PERIOD:
          earthdriver_angle += 0.01;
          break;
        case SDLK_SPACE: {
          if (sun_on || earth_on) {
            sun_on = earth_on = false;
          } else {
            sun_on = earth_on = true;
          }
          break;
        }
        case SDLK_ESCAPE:
          return 0;
        default:;
        }
      }

      default:;
      }
    }

    #if 0
    if (sun_on) sun_angle += -0.04 + 0.01 * sin(t/33);
    if (earth_on) earthdriver_angle += 0.02 * sin(t / 50) * sin(t / 21);
    #endif

    t += 1.0;
    Draw();
    SDL_Flip(screen);

    SDL_Delay(0);
  }

  return 0;
}
