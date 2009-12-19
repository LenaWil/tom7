
#ifndef __MENU_H
#define __MENU_H

#include "escapex.h"
#include <SDL.h>
#include "util.h"
#include "chars.h"

/* menus are essentially what are often called
   "forms" in GUI lingo */

enum resultkind { 
  MR_NOTHING, 
  /* go to the next or previous item */
  MR_NEXT, MR_PREV, 
  /* the key is rejected as illegal */
  MR_REJECT, 
  /* some action has changed the display
     (implied by next,prev) */
  MR_UPDATED,
  /* confirm or cancel the entire menu */
  MR_OK, MR_CANCEL,
  /* quit the program */
  MR_QUIT,
};

struct inputresult {
  resultkind k;
  virtual resultkind kind() { return k; }
  inputresult(resultkind i) : k(i) {}
};

/* XXX add a way of getting defaults */
/* (mostly) abstract base class of menuitems,
   which are "controls" in GUI lingo */
struct menuitem {

  /* perhaps multi-line explanation of what this
     control sets. */
  string explanation;

  /* how many pixels to indent by.
     this amount is interpreted as being automatically
     added to the width in size and the x value for
     draw. */
  int indent;

  /* if the control is disabled, it should not
     be focusable and should draw differently */
  bool disabled;

  /* parent menu */
  struct menu * container;

  /* stuff that all menuitems have */

  /* some controls can be focused, some not */
  virtual bool focusable() { return !disabled; }

  virtual void size(int & width, int & height) = 0;
  virtual void draw(int x, int y, int focused) = 0;

  /* mouse click relative to menuitem */
  virtual inputresult click(int x, int y) {
    /* XXX send key 'enter' */
    return inputresult(MR_REJECT);
  }

  /* displayed at the bottom of the screen to
     explain how to use the control */
  virtual string helptext() = 0;

  /* some default behavior here */
  /* process a keypress. 
     assume e.type = SDL_KEYDOWN */
  virtual inputresult key(SDL_Event e);

  menuitem() : indent(0), disabled(false) {}
  virtual ~menuitem () {}
};

struct textbox : public menuitem {
  virtual string helptext () {
    return "Use like a normal simple editor. " BLUE "Tab" POP " exits.";
  }
  virtual void draw(int x, int y, int f);
  virtual void size(int & w, int & h);
  virtual ~textbox () { empty (); }

  string get_text();
  /* puts cursor at the beginning, 0 scroll.
     might want to call goto_end after setting. */
  void set_text(string);

  virtual inputresult key(SDL_Event e);

  textbox(int cw, int ch) : 
    before(0), after(0), charsw(cw), charsh(ch) {}

  string question;

  void goto_beginning();
  void goto_end();

  private:
  /* we use a "red sea" implementation, where the cursor
     is the cleaving, and we insert new chars onto the head
     of before (which appears in reverse order) */
  vallist<char> * before;
  vallist<char> * after;

  int charsw, charsh;

  /* destroys before, after */
  void empty ();

  string prevline(vallist<char> *& bb);
  string nextword(vallist<char> *& aa);
  string popword(vallist<char> *& bb, char & p);
  void addstring(string);
  void type(char);
  void left(bool erasing);
  void left_noflow(bool);
  void up();
  void down();
  void right(bool erasing);
  int  countprevline(vallist<char> *& bb);
};

/* unselectable labels */
struct label : public menuitem {
  string text;
  virtual bool focusable () { return false; }
  virtual string helptext () { return ""; }
  virtual void draw(int x, int y, int f);
  virtual void size(int & w, int & h);
  virtual ~label() {}
};

/* empty space */
struct vspace : public menuitem {
  int height;
  vspace(int n) : height(n) {}
  virtual bool focusable () { return false; }
  virtual string helptext () { return ""; }
  virtual void draw(int x, int y, int f) { }
  virtual void size(int & w, int & h) { 
    w = 1;
    h = height;
  }
  virtual ~vspace() {}
};

struct textinput : public menuitem {
  string question;
  string input;
  /* immediately accept when pressing 'enter'? */
  bool accept_on_enter;

  virtual string helptext () { 
    return "Enter a single line of text.";
  }
  virtual void draw(int x, int y, int);
  virtual void draw_ch(int x, int y, int, char passwordchar = 0);
  virtual void size(int & w, int & h);
  virtual inputresult key(SDL_Event e);

  textinput () : accept_on_enter(false) {}

  virtual ~textinput() {}

  private:
  /* cursor before nth character in input */
  /* XXX probably want to check that the cursor is
     still inside 'input', because input can be
     changed externally */
  int cursor;
};

struct textpassword : public textinput {
  virtual string helptext () {
    return "Enter a password.";
  }
  virtual void draw(int x, int y, int i) {
    draw_ch(x, y, i, '*');
  }
  virtual ~textpassword () {}
};

struct toggle : public menuitem {
  string question;
  bool checked;

  virtual string helptext () { 
    return "Press " BLUE "enter" POP " or " 
      BLUE "space" POP " to toggle.";
  }
  virtual void draw(int x, int y, int);
  virtual void size(int & w, int & h);
  virtual inputresult key(SDL_Event e);
  virtual inputresult click(int, int);

  virtual ~toggle() {}

  private:

};

struct slider : public menuitem {
  string question;
  /* labels over lowest and highest points in slider */
  string low;
  string high;

  /* inclusive */
  int lowest;
  int highest;

  /* for best accuracy, nsegs should be
     (highest - lowest + 1). This directly affects
     the width. Therefore nsegs should be at
     least length(low) + length(hi) + 1 */
  int nsegs;

  virtual string helptext() {
    return "Press " BLUE "left" POP " or " BLUE "right" POP 
           " to change the setting.";
  }

  slider(int lows, int highs, int segs);
  virtual void draw(int x, int y, int f);
  virtual void size(int & w, int & h);
  virtual inputresult key(SDL_Event e);
  virtual inputresult click(int, int);

  virtual ~slider() {}

  /* selected position along line (value in the inclusive
     interval (lowest, highest)) */
  int pos;

  private:
  
  /* scrollbar graphic as string. has nseg segments */
  string scrollbar;
};

struct okay : public menuitem {
  string text;
  int * ptr;
  int myval;

  virtual string helptext() {
    return "Press " BLUE "enter" POP " to confirm.";
  }

  okay() {
    ptr = 0;
    myval = 0;
  }

  okay(string text_, int * ptr_ = 0, int myval_ = 0)
    : text(text_), ptr(ptr_), myval(myval_) {}

  virtual void draw(int x, int y, int f);
  virtual void size(int & w, int & h);

  virtual void activate() {
    /* set pointer if applicable */
    if (ptr) *ptr = myval;
  }

  virtual inputresult key(SDL_Event e);

  virtual inputresult click(int, int) {
    activate();
    return inputresult(MR_OK);
  }

  virtual ~okay() {}
};

struct cancel : public menuitem {
  string text;

  virtual string helptext() {
    return "Press " BLUE "enter" POP " to cancel. " 
           GREY "(" BLUE "esc" POP " also cancels at any time.)";
  }

  virtual void draw(int x, int y, int f);
  virtual void size(int & w, int & h);
  virtual inputresult key(SDL_Event e);

  virtual inputresult click(int, int) {
    return inputresult(MR_CANCEL);
  }

  virtual ~cancel() {}
};


/* menus */

struct menu : public drawable {

  /* create a menu from some items. After this point,
     it's not possible to add or remove items. If
     'fullscreen' is true, the menu uses the whole screen.
     Otherwise, it stretches to accomodate its contents
     and is centered on the screen. */
  /* does not take ownership of the item pointers
     or the list cells */
  static menu * create(drawable * below,
                       string title,
                       ptrlist<menuitem> * items,
                       bool fullscreen);

  virtual void draw();
  virtual void screenresize();

  /* enter modal mode and return the final result of
     the menu. expect MR_OK, MR_CANCEL, or MR_QUIT */
  resultkind menuize();

  /* all menuitems will still be available */
  virtual void destroy();
  virtual ~menu() {};

  int alpha;
  /* set negative to get centered behavior */
  int yoffset;

  private:

  menu() {
    items = 0;
    alpharect = 0;
    below = 0;
    selected = 0;
    alpha = 200;
    skip = 0;
    yoffset = -1;
  }

  void redraw();
  bool skip_ok(int);
  void fixup(int);
  void nextfocus(int dir);
  inputresult clickselect(int x, int y);

  drawable * below;
  string title;
  int nitems;
  menuitem ** items;
  bool fullscreen;
  int selected;
  int skip;

  int posx, posy;
  int w, h, stath;
  SDL_Surface * alpharect;

};

#endif
