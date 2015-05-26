
#ifndef __MESH_H
#define __MESH_H

#include <vector>

// Mesh is a 2D area that can be carved into. The current
// implementation just uses discrete pixels. Here, pixels are
// infinitely small dots arranged in a rectangular lattice.
// Their coordinates are their centers.

struct Mesh {
  // Creates a filled mesh of the given size (in units) and
  // resolution (total pixels in each dimension).
  Mesh(double width, double height,
       int xres, int yres);

  // Can carve circles (disks) only. Removes any pixels that are
  // inside the circle. Coordinates are unit offsets from (0, 0)
  // at the mesh's top-left corner.
  //
  // Note that if the circle is smaller than a pixel, it can actually
  // pass through the mesh without removing any. (And a radius of
  // sqrt(2) pixels can puncture the mesh without touching). Use a
  // finer mesh or bigger tool.
  void Carve(double cx, double cy, double radius);
  
  // Used for example to draw on the screen. Returns true if any pixel
  // is set within the circle. Equivalent to Density > 0.0.
  bool AnyPixelSet(double cx, double cy, double radius) const;

  // Return the density; the fraction of pixels that are set within
  // the circle. Used for drawing anti-aliased meshes, for example.
  double Density(double cx, double cy, double radius) const;

  double Width() const { return width; } 
  double Height() const { return height; } 

private:
  const double width, height;
  const int xres, yres;
  // Packed, row-major.
  std::vector<bool> pixels;
};


#endif
