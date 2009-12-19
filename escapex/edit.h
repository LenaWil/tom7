
#ifndef __EDIT_H
#define __EDIT_H

#include "escapex.h"
#include "play.h"
#include "level.h"
#include "player.h"
#include "draw.h"

#define EDIT_DIR "mylevels"

enum { RT_MAZE, RT_MAZE2, RT_CORRIDORS, RT_MAZEBUG1, RT_MAZEBUG2, 
       RT_ROOMS, RT_CRAZY, RT_RETRACT1, RT_RETRACTGOLD, NUM_RANDTYPES, };

struct editor : public drawable {

  /* takes ownership */
  void setlevel(level * l) {
    dr.lev = l;
  }

  void edit(level * origlev = 0);

  /* drawable */
  void draw();
  void screenresize();

  virtual ~editor();

  static editor * create(player * p);

  void destroy() {
    saved->destroy();
    delete this;
  }

  private:

  void redraw () {
    draw();
    SDL_Flip(screen);
  }

  bot currentbomb;

  int changed;

  player * plr;

  solution * saved;

  void tmenurotate(int n);
  void saveas();
  void settitle();
  void setauthor();
  void playerstart();
  void placebot(bot);
  void sleepwake();
  void erasebot();
  void firstbot();
  void save();
  void load();
  void resize();
  void clear(tile bg, tile fg);
  void playlev();
  void prefab();
  void pftimer();
  void pffile();
  void next_bombtimer();
  void fixup_botorder();
  bool clearbot(int x, int y);
  bool moveplayersafe();

  void fixup();
  bool timer_try(int *, int *, int, int, int n, bool rev);
  void addbot(int x, int y, bot b);

  void dorandom();
  void fullclear(tile);

  /* stuff for ai */
  void retract1();
  bool retract_grey ();
  bool retract_hole ();
  bool retract_gold();

  string ainame (int a);

  void videoresize(SDL_ResizeEvent * eventp);
  
  void setlayer(int x, int y, int t) {
    if (layer) {
      dr.lev->osettile(x, y, t);
    } else {
      dr.lev->settile(x, y, t);
    }
  }
  
  int layerat(int x, int y) {
    if (layer) {
      return dr.lev->otileat(x, y);
    } else {
      return dr.lev->tileat(x, y);
    }
  }

  void blinktile(int, int, Uint32);

  bool getdest(int & x, int & y, string msg);

  bool showdests;

  int tmenuscroll;
  /* 0 = real, 1 = bizarro */
  int layer;

  int olddest;

  int mousex, mousey;

  int current;

  string filename;

  drawing dr;

  int randtype;
  /* if this is set, then dragging should
     not drop tiles */
  bool donotdraw;

  /* if w=0 or h=0, then no selection */
  SDL_Rect selection;
  void clearselection() {
    selection.w = 0;
    selection.h = 0;
    selection.x = 0;
    selection.y = 0;
  }
};

#endif
