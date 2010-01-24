
#include "mainshow.h"

#define EXIT_FREQ 10
#define GUY_FREQ 40
#define LEVEL_FREQ 300

mainshow::mainshow(int w, int h, int zf) {
  dr.lev = level::defboard(w, h);
  dr.width = (TILEW >> zf) * w;
  dr.height = (TILEH >> zf) * h;
  dr.margin = 0;
  dr.scrollx = 0;
  dr.scrolly = 0;
  dr.zoomfactor = zf;

  tx = textscroll::create(fonsmall);
  tx->width = 100;
  tx->height = (TILEH >> zf) * h;

  newlevel();
}

mainshow::~mainshow() {
  dr.lev->destroy();
  dr.lev = 0;

  tx->destroy();
  tx = 0;
}

void mainshow::draw(int x, int y, SDL_Surface * surf) {
  if (!surf) surf = screen;
  dr.posx = x;
  dr.posy = y;
  dr.drawlev(0, surf, true);
  
  tx->posx = 4 + x + (TILEW >> dr.zoomfactor) * dr.lev->w;
  tx->posy = y;

  tx->drawto (surf);
}

void mainshow::step() {

  int dumb, dumby;
  dir dummy;
  if (dr.lev->isdead(dumb, dumby, dummy)) {
    tx->say(RED "Drat!");
    newguy();
  }

  if (dr.lev->iswon()) {
    tx->say(GREEN "Yeah!");
    newexit();
  }

  if (1 && !leveltime--) newlevel();
  if (1 && !exittime--)  newexit();
  if (1 && !guytime--)   newguy();

  trymove();

  tx->say("");
}

/* XXX facing is now in level, so this is just
   eta-expansion of move */
bool mainshow::moveface(dir d) {
  if (dr.lev->move(d)) {
    return true;
  } else return false;
}

void mainshow::trymove() {

  /* walk towards goal */
  level * l = dr.lev;
  int dx = 0, dy = 0;
  if (l->guyx < exitx) dx = 1;
  else if (l->guyx > exitx) dx = -1;

  if (l->guyy < exity) dy = 1;
  else if (l->guyy > exity) dy = -1;

  if (util::random() & 1) {
    /* prefer x */
    if (dx > 0 && moveface(DIR_RIGHT)) return;
    if (dx < 0 && moveface(DIR_LEFT)) return;

    if (dy > 0 && moveface(DIR_DOWN)) return;
    if (dy < 0 && moveface(DIR_UP)) return;

  } else {
    /* prefer y */

    if (dy > 0 && moveface(DIR_DOWN)) return;
    if (dy < 0 && moveface(DIR_UP)) return;

    if (dx > 0 && moveface(DIR_RIGHT)) return;
    if (dx < 0 && moveface(DIR_LEFT)) return;

  }

  /* if we can't make any move, reset faster */
  if (guytime > 1) guytime --;

}

void mainshow::randomspot(int & x, int & y) {

  int idx = 
    util::random () % ((dr.lev->w - 2) * (dr.lev->h - 2));

  x = 1 + idx % (dr.lev->w - 2);
  y = 1 + idx / (dr.lev->w - 2);

}

void mainshow::newexit() {

  dr.lev->settile(exitx, exity, T_FLOOR);

  randomspot(exitx, exity);

  dr.lev->settile(exitx, exity, T_EXIT);
  
  exittime = 5 + (util::random() % EXIT_FREQ);
}

void mainshow::newguy() {

  randomspot(dr.lev->guyx,
	     dr.lev->guyy);
  
  guytime = 8 + (util::random() % GUY_FREQ);
}

void mainshow::newlevel () {

  /* XXX make a more interesting random level!! 
     (we had better improve the AI, then)

     actually, the AI gets a big bonus by being
     randomly placed (and having a moving exit),
     so even if we just pulled random levels from
     the triage collection (at 18x10 or smaller),
     we'd probably win eventually. */ 
  for(int y = 0; y < dr.lev->h; y++) {
    for(int x = 0; x < dr.lev->w; x++) {
      dr.lev->settile(x, y, T_FLOOR);
      
      /* sometimes put something other than floor */
      if (!(util::random() & 127))
	dr.lev->settile(x, y, T_LASER);

      if (!(util::random() & 63))
	dr.lev->settile(x, y, T_BLUE);

      if (!(util::random() & 63))
	dr.lev->settile(x, y, T_GREY);

      if (!(util::random() & 63))
	dr.lev->settile(x, y, T_HOLE);

      if (!(util::random() & 63)) {
	dr.lev->settile(x, y, T_TRANSPORT);
	int dx = 1, dy = 1;
	randomspot(dx, dy);
	dr.lev->setdest(x, y, dx, dy);
      }


      if (x == 0 || x == (dr.lev->w - 1) ||
	  y == 0 || y == (dr.lev->h - 1)) 
	dr.lev->settile(x, y, T_BLUE);
    }
  }

  newguy();

  /* this clears the spot where the guy lives */
  exitx = dr.lev->guyx;
  exity = dr.lev->guyy;
  newexit();

  leveltime = 30 + (util::random() % LEVEL_FREQ);
}
