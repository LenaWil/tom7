
#include "textscroll.h"
#include "escapex.h"
#include "draw.h"

#define BACKLOG 256

struct tsreal : public textscroll {

  static tsreal * create(font * f);
  virtual void destroy();
  virtual void say(string s);
  virtual void unsay();

  /* drawable */
  virtual void draw();
  virtual void screenresize();

  virtual void drawto(SDL_Surface * surf = 0);

  virtual ~tsreal ();
  
  string log[BACKLOG];
  int pwrite;

  font * ft;

};

textscroll * textscroll :: create(font * f) {
  return tsreal::create(f);
}

tsreal :: ~tsreal () {}
textscroll :: ~textscroll () {}

void tsreal :: destroy () { delete this; }
void tsreal :: screenresize () {}

tsreal * tsreal :: create (font * f) {
  tsreal * ts = new tsreal();
  ts->ft = f;
  ts->posx = 0;
  ts->posy = 0;
  ts->vskip = 0;
  ts->height = screen->h;
  ts->width = screen->w;
  ts->pwrite = 0;
  return ts;
}

void tsreal::say(string s) {
  /* write new entry */
  log[pwrite] = s;
  pwrite ++;
  pwrite %= BACKLOG;
}

/* weird results if unsay() with
   an empty buffer */
void tsreal::unsay() {
  if (pwrite) {
    pwrite --;
    log[pwrite] = "";
  } else {
    pwrite = BACKLOG - 1;
    log[pwrite] = "";
  }
}

/* XXX word wrap would be desirable.
   It's a little tricky because we're
   going backwards, but it's still easier
   than going forwards */
void tsreal :: drawto (SDL_Surface * surf) {
  
  if (!surf) surf = screen;

  int y = (posy + height) - (ft->height + vskip);
  int l = pwrite?(pwrite-1):(BACKLOG-1);

  while(y > posy) {
    ft->drawto(surf, posx, y, log[l]);

    l --;
    if (l < 0) l = BACKLOG - 1;
    y -= (ft->height + vskip);
  }
}

void tsreal :: draw () { 
  drawto(screen); 
}

