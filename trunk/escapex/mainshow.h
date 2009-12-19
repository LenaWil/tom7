
#ifndef __MAINSHOW_H
#define __MAINSHOW_H

#include "draw.h"
#include "extent.h"
#include "version.h"
#include "util.h"
#include "prefs.h"
#include "chars.h"
#include "client.h"
#include "load.h"
#include "message.h"
#include "play.h"
#include "generator.h"
#include "textscroll.h"

/* draws an ever-changing and poorly-played level */

struct mainshow {
  
  /* width and height given in tiles */
  mainshow(int w, int h, int zf = 1);

  /* take a step. this can be about anything */
  void step();

  /* draw to x,y on the supplied surface. if surface is
     0, then draw to the screen */
  void draw(int x, int y, SDL_Surface * surf = 0);
  
  ~mainshow();

  int width() {
    return dr.width;
  }

private:
  
  drawing dr;

  void newlevel();
  void newexit();
  void newguy();
  bool moveface(dir);

  void trymove();
  void randomspot(int & x, int & y);

  int exitx;
  int exity;

  int leveltime;
  int exittime;
  int guytime;
  
  textscroll * tx;
  
};

#endif
