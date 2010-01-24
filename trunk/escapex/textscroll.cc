
#include "textscroll.h"
#include "escapex.h"
#include "draw.h"

#define BACKLOG 256

struct textscroll_ : public textscroll {

  static textscroll_ * create(font * f);
  virtual void destroy();
  virtual void say(string s);
  virtual void unsay();

  /* drawable */
  virtual void draw();
  virtual void screenresize();

  virtual void drawto(SDL_Surface * surf = 0);

  virtual ~textscroll_ ();
  
  string log[BACKLOG];
  int pwrite;

  font * ft;

};

textscroll * textscroll::create(font * f) {
  return textscroll_::create(f);
}

textscroll_::~textscroll_ () {}
textscroll::~textscroll () {}

void textscroll_::destroy () { delete this; }
void textscroll_::screenresize () {}

textscroll_ * textscroll_::create (font * f) {
  textscroll_ * ts = new textscroll_();
  ts->ft = f;
  ts->posx = 0;
  ts->posy = 0;
  ts->vskip = 0;
  ts->height = screen->h;
  ts->width = screen->w;
  ts->pwrite = 0;
  return ts;
}

void textscroll_::say(string s) {
  /* write new entry */
  log[pwrite] = s;
  pwrite ++;
  pwrite %= BACKLOG;
}

/* weird results if unsay() with
   an empty buffer */
void textscroll_::unsay() {
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
void textscroll_::drawto (SDL_Surface * surf) {
  
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

void textscroll_::draw () { 
  drawto(screen); 
}

