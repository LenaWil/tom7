
#include "font.h"
#include "sdlutil.h"

// XXX use std::unique_ptr or whatever.
namespace {
template <class P>
struct Extent {
  
  P * ptr;

  Extent(P * p) : ptr(p) {}

  void release() { ptr = 0; }

  void replace(P * p) { ptr = p; }

  ~Extent() { if (ptr) ptr->destroy(); }

};
}

enum attr { COLOR, ALPHA, };

struct font_attrlist {
  attr what;
  int value;

  font_attrlist * next;

  font_attrlist(attr w, int h, font_attrlist * n) : 
    what(w), value(h), next(n) {}

  /* PERF: we often have to look at the entire stack. */
  /* sets the current color and alpha according to the stack */
  static void set(font_attrlist * cs, int & c, int & a) {
    c = 0;
    a = 0;
    bool gotc = false, gota = false;

    while(cs && !(gotc && gota)) {
      switch(cs->what) {
      case COLOR: 
	if (!gotc) { c = cs->value; gotc = true; }
	break;
      case ALPHA: 
	if (!gota) { a = cs->value; gota = true; }
	break;
      }
      cs = cs -> next;
    }      
  }

  static int pop(font_attrlist *& il) {
    if (il) {
      font_attrlist * tmp = il;
      int t = tmp->value;
      il = il->next;
      delete tmp;
      return t;
    } else return 0;
  }

};

struct fontreal : public Font {

  /* data is an array of font images, differing in
     their alpha transparency */
  SDL_Surface ** data;
  SDL_Surface *screen;
  int ndim;

  unsigned char chars[255];

  static fontreal * create(SDL_Surface *screen,
			   string file,
			   string charmap,
			   int width,
			   int height,
			   int styles=1,
			   int overlap=0,
			   int ndim_=2);

  static fontreal * create_from_surface(SDL_Surface *screen,
					SDL_Surface *font_surface,
					string charmap,
					int width,
					int height,
					int styles=1,
					int overlap=0,
					int ndim_=2);

  virtual int sizex(const string &);
  virtual int sizex_plain(const string &);

  virtual void draw(int x, int y, string s);
  virtual void drawto(SDL_Surface *, int x, int y, string s);

  virtual void draw_plain(int x, int y, string s);
  virtual void drawto_plain(SDL_Surface *, int x, int y, string s);

  virtual void destroy() {
    if (data) {
      for(int i = 0; i < ndim; i ++) {
	if (data[i]) SDL_FreeSurface(data[i]);
      }
      free (data);
    }
    delete this;
  }

  virtual int drawlinesc(int x, int y, string, bool);
  virtual int drawlines(int x, int y, string);
  virtual int drawcenter(int x, int y, string);

  virtual ~fontreal();
};

Font::~Font() {}
fontreal::~fontreal() {}

Font * Font::create(SDL_Surface *sc, string f, string c,
		    int w, int h, int s, int o, int d) {
  return fontreal::create(sc, f, c, w, h, s, o, d);
}

Font * Font::create_from_surface(SDL_Surface *sc, SDL_Surface *fs, string c,
				 int w, int h, int s, int o, int d) {
  return fontreal::create_from_surface(sc, fs, c, w, h, s, o, d);
}


fontreal * fontreal::create_from_surface(SDL_Surface *screen,
					 SDL_Surface *font_surface,
					 string charmap,
					 int width,
					 int height,
					 int styles,
					 int overlap,
					 int ndim) {
  fontreal * f = new fontreal();
  if (!f) return 0;
  Extent<fontreal> fe(f);
  f->screen = screen;
  f->width = width;
  f->height = height;
  f->styles = styles;
  f->overlap = overlap;
  f->data = 0;
  f->ndim = ndim;

  if (!ndim) return 0;

  f->data = (SDL_Surface **)malloc(sizeof (SDL_Surface *) * ndim);
  if (!f->data) return 0;
  for(int z = 0; z < ndim; z++) f->data[z] = 0;

  f->data[0] = font_surface;

  int last = 0;
  while(last < (ndim - 1)) {
    last ++;
    f->data[last] = sdlutil::alphadim(f->data[last - 1]);
    if (!f->data[last]) return 0;
  }

  for(int j = 0; j < 255; j ++) {
    f->chars[j] = 0;
  }

  for(unsigned int i = 0; i < charmap.length (); i ++) {
    int idx = (unsigned char)charmap[i];
    f->chars[idx] = i;
  }

  fe.release ();
  return f;
}

fontreal * fontreal::create(SDL_Surface *screen,
			    string file,
			    string charmap,
			    int width,
			    int height,
			    int styles,
			    int overlap,
			    int ndim) {
  SDL_Surface *fon = sdlutil::LoadImage(file.c_str());
  if (!fon) return 0;
  return create_from_surface(screen, fon, charmap, 
			     width, height, styles, overlap, ndim);
}

void fontreal::draw(int x, int y, string s) {
  drawto(screen, x, y, s);
}

void fontreal::draw_plain(int x, int y, string s) {
  drawto_plain(screen, x, y, s);
}

void fontreal::drawto_plain(SDL_Surface * surf, int x, int y, string s) {

  SDL_Rect src, dest;

  dest.x = x;
  dest.y = y;

  src.w = width;
  src.h = height;

  for(unsigned int i = 0; i < s.length(); i ++) {

    int idx = (unsigned char)s[i];
    src.x = chars[idx] * width;
    src.y = 0;
  
    SDL_BlitSurface(data[0], &src, surf, &dest);

    dest.x += (width - overlap);
  }
}

void fontreal::drawto(SDL_Surface * surf, int x, int y, string s) {

  SDL_Rect src, dest;
  /* XXX can't init these once, since blit can side-effect fields
     (try drawing off the screen) */
  dest.x = x;
  dest.y = y;

  src.w = width;
  src.h = height;

  /* keep track of our color and alpha settings */
  font_attrlist * cstack = 0; 
  int color, alpha;
  font_attrlist::set(cstack, color, alpha);

  for(unsigned int i = 0; i < s.length(); i ++) {

    if ((unsigned char)s[i] == '^') {
      if (i < s.length()) {
	i++;
	switch((unsigned char)s[i]) {
	case '^': break; /* quoted... keep going */
	case '<': /* pop */
	  if (cstack) font_attrlist::pop(cstack);
	  font_attrlist::set(cstack, color, alpha);
	  continue;
	default:
	  if (s[i] >= '#' && s[i] <= '\'') {
	    /* alpha */
	    cstack =
	      new font_attrlist(ALPHA,
				abs((unsigned char)s[i] - '#') % ndim,
				cstack);
	  } else {
	    /* color */
	    cstack = 
	      new font_attrlist(COLOR,
				abs(((unsigned char)s[i] - '0')
				    % styles),
				cstack);
	  }

	  font_attrlist::set(cstack, color, alpha);
	  continue;
	}
      }
    }

    /* current color */

    int idx = (unsigned char)s[i];
    src.x = chars[idx] * width;
    src.y = color * height;
  
    SDL_BlitSurface(data[alpha], &src, surf, &dest);

    dest.x += (width - overlap);
  }

  /* empty list */
  while(cstack) font_attrlist::pop(cstack);

}

int fontreal::sizex_plain(const string & s) {
  return s.length () * (width - overlap);
}

int fontreal::sizex(const string & s) {
  return Font::length(s) * (width - overlap);
}

int fontreal::drawlines(int x, int y, string s) {
  return drawlinesc(x, y, s, false);
}

int fontreal::drawcenter(int x, int y, string s) {
  return drawlinesc(x, y, s, true);
}


/* XXX doesn't handle color codes that span lines. */
int fontreal::drawlinesc(int x, int y, string s, bool center) {
  
  int start = 0;
  unsigned int idx = 0;
  /* draw every non-empty string delimited by \n */
  int offset = 0;
  int wroteany = 0;
  for(;;idx ++) {
  again:;
    /* reached end of string? */
    if (idx >= s.length()) {
      if (wroteany) {
	int xx;
	string sub = s.substr(start, idx - start);
	if (center) {
	  xx = x - (sizex(sub) >> 1);
	} else xx = x;

	draw(xx, y + offset, sub);
	return offset + height;
      } else return offset;
    }
     
    if (s[idx] == '\n') {
      int xx;
      string sub = s.substr(start, idx - start);
      if (center) {
	xx = x - (sizex(sub) >> 1);
      } else xx = x;
      draw(xx, y + offset, sub);
      offset += height;
      start = idx + 1;
      idx = idx + 1;
      wroteany = 0;
      goto again;
    } else wroteany = 1;
  }
}

/* by example:
   "" returns 0
   "\n" returns 1
   "hello" returns 1
   "hello\n" returns 1
   "hello\nworld" returns 2
   "hello\nworld\n" returns 2
*/
int Font::lines(const string & s) {
  unsigned int idx = 0;
  int sofar = 0;

  enum mode { M_FINDANY, M_STEADY, };

  mode m = M_FINDANY;

  for(;;idx++) {
    if (idx >= s.length()) return sofar;
    switch(m) {
    case M_FINDANY:
      if (s[idx] == '\n') {
	sofar++;
	continue;
      } else {
	sofar++;
	m = M_STEADY;
	continue;
      }
    case M_STEADY:
      if (s[idx] == '\n') {
	m = M_FINDANY;
	continue;
      }
    }
  }
}

string Font::substr(const string & s, unsigned int start, unsigned int len) {
  /* skip 'start' chars */

  unsigned int i = 0; /* pos in fontstring */
  unsigned int j = 0; /* number of actual chars seen */

  for(; i < s.length() && j < start; i ++) {

    if ((unsigned char)s[i] == '^') {
      if (i < s.length()) {
	i++;
	if ((unsigned char)s[i] == '^') j++;
      } else j ++; /* ??? */
    } else j ++;

  }

  j = i;
  /* substring will start at j; now count
     'len' chars to find end */

  unsigned int k = 0;
  /* XXX should also add any trailing
     control codes */
  for(; i < s.length() && k < len; i ++) {

    if ((unsigned char)s[i] == '^') {
      if (i < s.length()) {
	i++;
	if ((unsigned char)s[i] == '^') j++;
      } else k ++; /* ??? */
    } else k ++;

  }

  return s.substr(j, i - j);
}

/* assume n <= font::length(s) */
string Font::prefix(const string & s, unsigned int n) {
  return Font::substr(s, 0, n);
}

/* assume n <= font::length (s) */
string Font::suffix(const string & s, unsigned int n) {
  return Font::substr(s, Font::length(s) - n, n);
}

unsigned int Font::length(string s) {
  unsigned int i, n=0;
  for(i = 0; i < s.length(); i ++) {
    if ((unsigned char)s[i] == '^') {
      if (i < s.length()) {
	i++;
	if ((unsigned char)s[i] == '^') n++;
      } else n ++; /* ??? */
    } else n ++;
  }
  return n;
}

/* XXX should go to fontutil */
#include "chars.h"
string Font::pad(const string & s, int ns) {
  unsigned int l = Font::length(s);
    
  unsigned int n = abs(ns);

  if (l > n) {
    return truncate(s, ns);
    // return font::prefix(s, n - 3) + (string)ALPHA50 "..." POP;
  } else {
    string ou;
    /* PERF there's definitely a faster way to do this */
    for(unsigned int j = 0; j < (n - l); j ++) ou += " ";
    if (ns > 0) {
      return s + ou;
    } else {
      return ou + s;
    }
  }
}

string Font::truncate(const string & s, int ns) {
  unsigned int l = Font::length(s);

  unsigned int n = abs(ns);
  if (l > n) {
    if (ns > 0) {
      return Font::prefix(s, n - 3) + (string)ALPHA50 "..." POP;
    } else {
      return (string)ALPHA50 "..." POP + Font::suffix(s, n - 3);
    }
  } else return s;

}
