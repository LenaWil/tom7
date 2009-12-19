
#include "drawable.h"

struct nodraw_t : public drawable {
  virtual void draw() {}
  virtual void screenresize() {}
};

/* singleton no-draw object */
drawable * nodraw;

void drawable::init() {
  nodraw = new nodraw_t();
}
