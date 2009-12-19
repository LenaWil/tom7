
#ifndef __DIRT_H
#define __DIRT_H

struct dirt {
  
  /* bring up-to-date with the screen.
     (expensive). Should be called whenever
     the screen size changes.

     erases the dirty list. */
  virtual void mirror() = 0;

  /* call if the screen is resized */
  virtual void matchscreen() = 0;
  
  /* PERF could offer mirror_region, which
     allows us to do more local dirtyrect stuff
     by predicting the regions that we will
     need to mirror */
  
  /* enqueue a rectangle to be drawn from the
     mirror. */
  virtual void setdirty(int x, int y, int w, int h) = 0;

  /* draw all enqueued dirty rectangles. */
  virtual void clean() = 0;

  virtual void destroy() = 0;

  static dirt * create();

  virtual ~dirt () {}

};

#endif
