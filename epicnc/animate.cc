
#include <vector>
#include <utility>
#include <tuple>
#include <cstdint>
#include <math.h>

#include "SDL.h"
#include "sdl/sdlutil.h"
#include "../cc-lib/sdl/chars.h"
#include "../cc-lib/sdl/font.h"

#include "point.h"
#include "inversion.h"
#include "base/stringprintf.h"
#include "mesh.h"


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
#define SQRT_2 1.41421356237309504880168872420969807856967187537694807317667

#define FONTWIDTH 9
#define FONTHEIGHT 16

#define STARTW 1920
#define STARTH 1080

#define DRAWMARGINX 12
#define DRAWMARGINY 12

// TODO: Make into little library. Make constexpr mixcolor that's
// correct for the platform.
static constexpr uint32 RGBA(uint8 r, uint8 g, uint8 b, uint8 a) {
  return (a << 24) |
    (b << 16) |
    (g << 8) |
    r;
}
static constexpr uint32 C_RED = RGBA(0xFF, 0x0, 0x0, 0xFF);
static constexpr uint32 C_BLACK = RGBA(0x0, 0x0, 0x0, 0xFF);
static constexpr uint32 C_WHITE = RGBA(0xFF, 0xFF, 0xFF, 0xFF);
static constexpr uint32 C_GREEN = RGBA(0x0, 0xFF, 0x0, 0xFF);
static constexpr uint32 C_BLUE = RGBA(0x0, 0x0, 0xFF, 0xFF);
static constexpr uint32 C_BACKGROUND = RGBA(0x00, 0x20, 0x00, 0xFF);

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
  sdlutil::clearsurface(screen, C_BACKGROUND);
  SDL_Flip(screen);

  Font *font = Font::create(screen,
			    "font.png",
			    FONTCHARS,
			    FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);

  // All angles in radians, distances in "units".

  // Diameter of big base gear.
  double sun_dia = 6.0;
  // Diameter of big nested gear.
  double earth_dia = 3.9;
  // Center of earth to center of sun.
  double orbit = 2.413;
  // Distance from earth's center to its wand's tip.
  double wand_length = orbit;

  double drill_dia = 0.25;
  double drill_angle = 0;

  // XXX make accurate
  double earth_gear_ratio = 4.0;
  const double earthdriver_dia = earth_dia / earth_gear_ratio;

  double sun_gear_ratio = 6.0;
  const double sundriver_dia = sun_dia / sun_gear_ratio;

  const double sundriver_location_angle = (5.0 / 8.0) * TWOPI;
  const double sundriver_center_distance = (sun_dia + sundriver_dia) * 0.5;
  const double sundriver_x = sin(sundriver_location_angle) *
    sundriver_center_distance;
  const double sundriver_y = cos(sundriver_location_angle) *
    sundriver_center_distance;

  // Both sun and earth are externally driven. The sun is a simple
  // gear mesh. The earth's driver has an interaction with the sun,
  // however.
  //
  // Both in mechanism-space.
  double sundriver_angle = 0.0;
  double earthdriver_angle = 0.0;

  struct Configuration {
    double sun_angle = 0.0;
    double earth_x = 0.0, earth_y = 0.0;
    double earth_angle = 0.0;
    double wand_x = 0.0, wand_y = 0.0;
  };

  auto Compute = [sun_dia, earth_dia, orbit, wand_length,
		  sun_gear_ratio,
                  earth_gear_ratio, earthdriver_dia]
    (double sd_a, double ed_a) -> Configuration {

    Configuration c;

    c.sun_angle = sd_a / -sun_gear_ratio;

    // Earth's center.
    c.earth_x = sin(c.sun_angle) * orbit;
    c.earth_y = cos(c.sun_angle) * orbit;

    // The earth driver and earth would be in a normal gearing
    // relationship, but the earth orbits the earth driver as well
    // (because it is on the sun), causing a kind of phantom rotation.
    const double effective_angle = ed_a - c.sun_angle;

    c.earth_angle = effective_angle / -earth_gear_ratio;

    c.wand_x = sin(c.earth_angle) * wand_length + c.earth_x;
    c.wand_y = cos(c.earth_angle) * wand_length + c.earth_y;

    return c;
  };

  const double max_radius = wand_length + orbit;

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
                              uint32 color = C_WHITE) {
    int sx0, sy0, sx1, sy1;
    std::tie(sx0, sy0) = ToScreen(x0, y0);
    std::tie(sx1, sy1) = ToScreen(x1, y1);
    sdlutil::drawclipline(screen, sx0, sy0, sx1, sy1,
                          (color >> 24) & 255,
                          (color >> 16) & 255,
                          (color >> 8) & 255);
  };

  auto DrawThickLine = [&ToScreen](double x0, double y0, double x1, double y1,
				   uint32 color = C_WHITE) {
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

      DrawLine(x, y, xx, yy, C_WHITE);
      x = xx;
      y = yy;
    }
  };

  auto DrawPoint = [&DrawLine](double x, double y) {
    DrawLine(x, y, x, y);
  };

  Pt prev{0.0, 0.0};
  vector<pair<Pt, Pt>> path;

  // XXX this also needs a rotation..
  // x,y are its top left
  auto DrawMeshAligned = 
    [&ToScreen, &ToMechanism](const Mesh &m, double x, double y) {

    int sx0, sy0, sx1, sy1;
    std::tie(sx0, sy0) = ToScreen(x, y);
    std::tie(sx1, sy1) = ToScreen(x + m.Width(), y + m.Height());
    
    //    printf("%d %d to %d %d\n", sx0, sy0, sx1, sy1);

    // Circle of size SQRT_2 can't miss pixels in a square grid.
    static constexpr double TEST_RADIUS = UNITS_PER_PIXEL * SQRT_2;

    // Loop over screen pixels.
    for (int py = sy0; py < sy1; py++) {
      double mesh_y = ((py - sy0) + 0.5) * UNITS_PER_PIXEL;
      for (int px = sx0; px < sx1; px++) {
	double mesh_x = ((px - sx0) + 0.5) * UNITS_PER_PIXEL;
	double dens = m.Density(mesh_x, mesh_y, TEST_RADIUS);
	uint8 red = dens * 255;
	sdlutil::drawclippixel(screen, px, py, red, 0, 0);
      }
    }

  };
  (void)DrawMeshAligned;

  // Draw a mesh with its CENTER at world coordinates x,y and
  // at the given angle.
  auto DrawMesh = 
    [&ToScreen, &ToMechanism](const Mesh &m, double cx, double cy,
			      double angle) {
    // Don't do trig for each pixel. Compute the locations of the
    // corners and interpolate between them.
    //
    // Length of the vector from the center to any corner.
    double len = 0.5 * sqrt(m.Width() * m.Width() + 
			    m.Height() * m.Height());
    
    // angle of top-left corner. Note both should be scaled by 0.5, but
    // this is the same angle. Note atan2 takes y, x.
    //
    // Be careful here since to atan2, -inf,-inf is the bottom-left
    // quadrant, not the top-left.
    double top_left_angle = atan2(-m.Height(), +m.Width()) + angle;
    double top_right_angle = atan2(-m.Height(), -m.Width()) + angle;
    double bottom_right_angle = top_left_angle + PI;
    double bottom_left_angle = top_right_angle + PI;

    // In world coordinates.
    // PERF some opportunity to reduce trig here.
    Pt top_left(cx + sin(top_left_angle) * len,
		cy + cos(top_left_angle) * len);
    Pt top_right(cx + sin(top_right_angle) * len,
		 cy + cos(top_right_angle) * len);
    Pt bottom_left(cx + sin(bottom_left_angle) * len,
		   cy + cos(bottom_left_angle) * len);
    Pt bottom_right(cx + sin(bottom_right_angle) * len,
		    cy + cos(bottom_right_angle) * len);

    Pt vecx(top_right.x - top_left.x,
	    top_right.y - top_left.y);
    Pt vecy(bottom_left.x - top_left.x,
	    bottom_left.y - top_left.y);

    for (int y = 0; y < m.YRes(); y++) {
      double yf = y / (double)m.YRes();
      for (int x = 0; x < m.XRes(); x++) {
	double xf = x / (double)m.XRes();

	const bool pixel = m.PixelAt(x, y);
	if (pixel) {
	  // XXX draw a rectangle if bigger than a pixel.

	  int px, py;
	  // XXX put in center of mesh cell.
	  std::tie(px, py) = ToScreen(top_left.x + 
				        vecx.x * xf + vecy.x * yf,
				      top_left.y +
				        vecx.y * xf + vecy.y * yf);
	  sdlutil::drawclippixel(screen, px, py, 255, 0, 0);
	}
      }
    }

    // draws x and y axes; not necessary...
    {
      int tx, ty, bx, by, cx, cy;
      std::tie(tx, ty) = ToScreen(top_left.x, top_left.y);
      std::tie(bx, by) = ToScreen(top_left.x + vecx.x,
				  top_left.y + vecx.y);
      std::tie(cx, cy) = ToScreen(top_left.x + vecy.x,
				  top_left.y + vecy.y);
      sdlutil::drawclipline(screen, tx, ty, bx, by, 0, 255, 255);
      sdlutil::drawclipline(screen, tx, ty, cx, cy, 255, 0, 255);
    }
  };

  // Very low res!!!
  Mesh mesh{sun_dia, sun_dia, 256, 256};

  auto MapDrill = [orbit, &mesh, &Compute](Pt in) -> Pt {
    // Find the drill's position relative to earth; this will
    // draw into the mesh.
    //
    // Just pretend earth is at angle 0, and find the coordinates
    // of the drill relative to to earth's center.
    const Configuration c = Compute(in.x, in.y);
      
    // in world coordinates
    const double drillx = orbit; // sin(0) * orbit
    const double drilly = 0.0; // cos(0)
      
    const double drillx_in_earth = drillx - c.earth_x;
    const double drilly_in_earth = drilly - c.earth_y;
      
    // Now, we can rotate it around earth's center. It has the
    // same center as earth, so its angle is just earth's angle.
      
    const double sint = sin(c.earth_angle + PI*0.5);
    const double cost = cos(c.earth_angle + PI*0.5);
    const double dxx = drillx_in_earth * cost - drilly_in_earth * sint;
    const double dyy = drillx_in_earth * sint + drilly_in_earth * cost;

    // And the mesh's 0,0 is actually its top left.
    return Pt(dxx + mesh.Width() * 0.5,
	      dyy + mesh.Height() * 0.5);
  };


  auto MapWand = [&Compute](Pt in) {
    const Configuration c = Compute(in.x, in.y);
    return Pt{c.wand_x, c.wand_y};
  };

  InvertRect<decltype(MapWand)> inv_wand{
    MapWand,
      0.0, TWOPI * sun_gear_ratio,
      0.0, TWOPI * earth_gear_ratio,
      -max_radius, max_radius,
      -max_radius, max_radius};

  InvertRect<decltype(MapDrill)> inv_drill{
    MapDrill,
      // Min/max angles for sun, earth drivers
      0.0, TWOPI * sun_gear_ratio,
      0.0, TWOPI * earth_gear_ratio,
      drill_dia * -0.5, mesh.Width() + drill_dia * 0.5,
      drill_dia * -0.5, mesh.Height() + drill_dia * 0.5};
  printf("Done.\n");

  enum Mode {
    MODE_WAND,
    MODE_DRAW,
  };

  Mode mode = MODE_DRAW;

  double tt = 0;
  auto Draw = [&font,
	       &sundriver_angle, &sundriver_x, &sundriver_y,
	       &sundriver_dia,
               &earthdriver_dia, &earthdriver_angle,
               &sun_dia, &earth_dia, &earth_gear_ratio,
               &wand_length, &orbit,
               &prev, &path,
               &Compute, &tt,
	       &inv_wand,
	       &ToMechanism,
	       &mesh, &DrawMesh, &DrawMeshAligned,
	       &drill_dia, &drill_angle,
               &DrawGear, &DrawPoint, &DrawLine, &DrawThickLine,
	       &mode]() {
    sdlutil::clearsurface(screen, C_BACKGROUND);

    Configuration c = Compute(sundriver_angle, earthdriver_angle);

    font->drawto(screen, STARTW / 2, 0,
		 (mode == MODE_WAND) ? 
		 "[W]and mode  [d]raw mode" :
		 "[w]and mode  [D]raw mode");

    font->drawto(screen, STARTW - 300, 0,
		 StringPrintf("sund ^2%.4f^< earthd ^3%.4f^<",
			      sundriver_angle, earthdriver_angle));
    // TODO more derived parameters.

    // Draw path.
    for (const auto p : path) {
      DrawThickLine(p.first.x, p.first.y, p.second.x, p.second.y, C_BLUE);
    }

    const Pt top_left = ToMechanism(DRAWMARGINX, DRAWMARGINY);
    DrawMeshAligned(mesh, top_left.x, top_left.y);

    // Mesh is centered on the Earth.
    DrawMesh(mesh, c.earth_x, c.earth_y, c.earth_angle);

    // Sun driver.
    DrawGear(sundriver_x, sundriver_y, sundriver_dia / 2.0,
	     sundriver_angle, 9);
    // Sun.
    DrawGear(0, 0, sun_dia / 2.0, c.sun_angle, 19);
    // Earth driver.
    DrawGear(0, 0, earthdriver_dia / 2.0, earthdriver_angle, 5);

    DrawPoint(c.earth_x, c.earth_y);

    DrawGear(c.earth_x, c.earth_y, earth_dia / 2, c.earth_angle, 20);

    // Draw the drill bit.
    DrawGear(orbit, 0, drill_dia / 2, drill_angle, 9);

    // Draw the wand.
    DrawLine(c.earth_x, c.earth_y, c.wand_x, c.wand_y, C_GREEN);
  };

  bool holding_rmb = false;

  bool sun_on = true, earth_on = true;
  double t = 0.0;
  while(1) {
    SDL_Event event;
    /* event loop */
    while (SDL_PollEvent(&event)) {
      switch(event.type) {
      case SDL_QUIT:
        return 0;
	
      case SDL_MOUSEBUTTONUP:
      case SDL_MOUSEBUTTONDOWN: {
	SDL_MouseButtonEvent *e = (SDL_MouseButtonEvent*)&event;
	if (e->button == SDL_BUTTON_RIGHT) {
	  holding_rmb = e->type == SDL_MOUSEBUTTONDOWN;
	}
	break;
      }

      case SDL_MOUSEMOTION: {
	SDL_MouseMotionEvent *e = (SDL_MouseMotionEvent*)&event;
	int mousex = e->x;
	int mousey = e->y;

	if (mode == MODE_DRAW) {
	  double mx = (mousex - DRAWMARGINX) * UNITS_PER_PIXEL;
	  double my = (mousey - DRAWMARGINY) * UNITS_PER_PIXEL;

	  // Only do this if we're on the mesh.
	  if (mx >= drill_dia * -0.5 && 
	      my >= drill_dia * -0.5 &&
	      mx <= mesh.Width() + drill_dia * 0.5 &&
	      my <= mesh.Height() + drill_dia * 0.5) {

	    // mx, my are correct (I plotted them)

	    Pt current{sundriver_angle, earthdriver_angle};
	    Pt output{mx, my};
	    Pt input;
	    if (inv_drill.Invert(current, output, &input)) {
	      sundriver_angle = input.x;
	      earthdriver_angle = input.y;
	    }
	  }

	} else if (mode == MODE_WAND) {

	  Configuration old = Compute(sundriver_angle, earthdriver_angle);
	  Pt output = ToMechanism(mousex, mousey);
	  Pt cur{sundriver_angle, earthdriver_angle};
	  Pt input;
	  if (inv_wand.Invert(cur, output, &input)) {

	    sundriver_angle = input.x;
	    earthdriver_angle = input.y;

	    if (e->state & SDL_BUTTON_LMASK) {
	      Configuration updated = Compute(sundriver_angle,
					      earthdriver_angle);
	      path.emplace_back(Pt{old.wand_x, old.wand_y},
				Pt{updated.wand_x, updated.wand_y});
	    }

	  } else {
	    // Unreachable!
	  }
	}
	break;
      }

      case SDL_KEYDOWN: {
        int key = event.key.keysym.sym;
        switch(key) {
	case SDLK_w:
	  mode = MODE_WAND;
	  break;

	case SDLK_d:
	  mode = MODE_DRAW;
	  break;

        case SDLK_s:
          sun_on = !sun_on;
          break;
        case SDLK_e:
          earth_on = !earth_on;
          break;
        case SDLK_z:
          sundriver_angle -= 0.01;
          break;
        case SDLK_x:
          sundriver_angle += 0.01;
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
    if (sun_on) sundriver_angle += -0.04 + 0.01 * sin(t/33);
    if (earth_on) earthdriver_angle += 0.02 * sin(t / 50) * sin(t / 21);
    #endif

    // Decorative
    if (holding_rmb) drill_angle += TWOPI * 0.1;

    // XXX move to end
    t += 1.0;
    Draw();


    if (holding_rmb) {
      // Carve from mesh; test.
      Pt meshcarve = MapDrill(Pt(sundriver_angle, earthdriver_angle));
      mesh.Carve(meshcarve.x, meshcarve.y, drill_dia * 0.5);
    }

    SDL_Flip(screen);

    SDL_Delay(0);
  }

  return 0;
}
