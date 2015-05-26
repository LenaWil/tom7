
#include "mesh.h"
#include <vector>

using namespace std;

namespace {
// An iteration over the clipped bounding rectangle of a circle,
// with a test for actually being in the circle.
struct Cir {
  inline Cir(double cx, double cy, double radius,
	     double w, double h, int xres, int yres) 
    : cx(cx), cy(cy),
      pixel_width(w / xres),
      pixel_height(h / yres),
      rsquared(radius * radius) {
    // Round down.
    xstart = (cx - radius) / pixel_width;
    if (xstart < 0) xstart = 0;
    ystart = (cy - radius) / pixel_height;
    if (ystart < 0) ystart = 0;
    
    // Round up. Note this is one past the end.
    xend = 1 + (cx + radius) / pixel_width;
    if (xend > xres) xend = xres;
    yend = 1 + (cy + radius) / pixel_height;
    if (yend > yres) yend = yres;
  }
  
  // Bounding rectangle spans [ystart, yend) and [xstart, xend).
  // These pixels are guaranteed to be in bounds of 'pixels' but
  // not necessarily in the circle.
  int ystart, xstart;
  int yend, xend;
  inline bool InCircle(int x, int y) {
    // Pixel to mesh units. Note the pixel is offset to its center.
    double mx = (x + 0.5) * pixel_width;
    double my = (y + 0.5) * pixel_height;
    
    double dx = mx - cx;
    double dy = my - cy;
    
    return (dx * dx) + (dy * dy) <= rsquared;
  }

 private:
  const double cx, cy;
  const double pixel_width, pixel_height;
  const double rsquared;
};
}

Mesh::Mesh(double w, double h, int xres, int yres)
  : width(w), height(h),
    xres(xres), yres(yres),
    pixels(xres * yres, true) {

}

void Mesh::Carve(double cx, double cy, double radius) {
  Cir cir{cx, cy, radius, width, height, xres, yres};
  for (int y = cir.ystart; y < cir.yend; y++) {
    for (int x = cir.xstart; x < cir.xend; x++) {
      if (cir.InCircle(x, y)) {
	pixels[y * yres + x] = false;
      }
    }
  }
}

bool Mesh::AnyPixelSet(double cx, double cy, double radius) const {
  Cir cir{cx, cy, radius, width, height, xres, yres};
  for (int y = cir.ystart; y < cir.yend; y++) {
    for (int x = cir.xstart; x < cir.xend; x++) {
      // Circle test second; it's more expensive.
      if (pixels[y * yres + x] && cir.InCircle(x, y)) {
	return true;
      }
    }
  }
  return false;
}

double Mesh::Density(double cx, double cy, double radius) const {
  Cir cir{cx, cy, radius, width, height, xres, yres};
  int num = 0, denom = 0;
  for (int y = cir.ystart; y < cir.yend; y++) {
    for (int x = cir.xstart; x < cir.xend; x++) {
      // XXX This is wrong for circles that get clipped.
      if (cir.InCircle(x, y)) {
	denom++;
	if (pixels[y * yres + x]) {
	  num++;
	}
      }
    }
  }

  return num / (double)denom;
}
