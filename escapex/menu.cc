
#include "menu.h"
#include "draw.h"
#include "chars.h"
#include "message.h"

/* PERF: can optimize many of these width calculations.
   PERF: no need to append strings so often */

#define TOPBARHEIGHT (fon->height * 2 + 4)

void slider::size(int & w, int & h) {
  w = fon->sizex(scrollbar + " " + question);
  h = fon->height + fonsmall->height + 2;
}

inputresult slider::key(SDL_Event e) {
  int key = e.key.keysym.sym;

  switch(key) {
  case SDLK_RIGHT:
    pos ++; break;
  case SDLK_LEFT: 
    pos --; break;
  default: return menuitem::key(e);
  }

  if (pos < lowest) pos = lowest;
  if (pos > highest) pos = highest;

  return inputresult(MR_UPDATED);
}

inputresult slider::click(int x, int y) {
  int sidew = fon->sizex(question + " ");

  int restw = (nsegs - 1) * (fon->width - fon->overlap);

  /* subtract half a gap size */
  x -= 
    (int)
    (0.5f * 
     /* size of bar */
     ((fon->width - fon->overlap) * (nsegs - 1) /
      /* number gaps */
      (float)(highest - lowest)));
     
  int newpos = (int)(((float)(x - sidew) / restw) * (highest - lowest));

  int maxpos = (highest - lowest);

  if (newpos < 0) newpos = 0;
  if (newpos > maxpos) newpos = maxpos;
  
  pos = newpos;

  return inputresult(MR_UPDATED);
}

void slider::draw(int xpos, int ypos, int foc) {
  int off = fon->sizex(question + " ");

  fon->draw(xpos, ypos + (fon->height / 3), 
	    disabled?(GREY + question):question);
  
  fon->draw(xpos + off, ypos, scrollbar);

  /* draw the slider thing now */
  float interval = (float)(highest - lowest);
  float sof = (float)(pos - lowest);
  int pixels = (nsegs - 1) * (fon->width - fon->overlap);
  int sp = (int)((sof / interval) * pixels);

  fon->draw(xpos + off + sp, ypos, PICS SLIDEKNOB);

  /* labels are small... */
  fonsmall->draw(xpos + off, ypos + fon->height, (foc?YELLOW:GREY) + low);
  int highlen = fonsmall->sizex(high);
  fonsmall->draw(xpos + off + pixels - highlen + fonsmall->width, 
		 ypos + fon->height, (foc?YELLOW:GREY) + high);
}

slider::slider(int lows, int highs, int segs)
  : lowest(lows), highest(highs), nsegs(segs) {

  pos = lowest + ((highest - lowest) / 2);
  scrollbar = PICS SLIDELEFT;
  for(int i = 0; i < (nsegs - 2); i ++) {
    scrollbar += SLIDE;
  }
  scrollbar += SLIDERIGHT POP;
}

void toggle::size(int & w, int & h) {
  w = fon->sizex(question + " [ ]");
  h = fon->height;
}

void toggle::draw(int xpos, int ypos, int f) {
  string pre = disabled?GREY:"";
  fon->draw(xpos, ypos,
	    pre + 
	    (string)"[" + 
	    " "
	    //	    (checked?YELLOW "X" POP:" ") +
	    "] " + 
	    (f?YELLOW:"") + question);

  if (checked)
    fon->draw(xpos + (fon->width >> 1) - fon->overlap,
	      ypos,
	      YELLOW LCHECKMARK POP);
}

inputresult toggle::key(SDL_Event e) {
  int kk = e.key.keysym.sym;

  switch(kk) {
  case SDLK_RETURN:
  case SDLK_SPACE:
    checked = !checked;
    return inputresult(MR_UPDATED);
  default: return menuitem::key(e);
  }

}

inputresult toggle::click(int x, int y) {
  checked = !checked;
  return inputresult(MR_UPDATED);
}

void label::size(int & w, int & h) {
  h = fon->height;
  w = fon->sizex(text);
}

void label::draw(int xpos, int ypos, int f) {
  /* never focused */
  fon->draw(xpos, ypos, text);
}


/* XXX allow cursor to move within input */
/* XXX add 'cursor' graphic to font */
/* XXX draw differently when disabled */
void textinput::draw_ch(int xpos, int ypos, int f, char c) {
  string i = input;
  
  if (c) {
    for(unsigned int x = 0; x < i.length(); x ++) i[x] = c;
  }

  /* allow string to end with ^ */
  if (i.length() > 0 && i[i.length() - 1] == '^') i += '^';

  if (f) {
    fon->draw(xpos, ypos, (string)YELLOW + question + POP
	      " " + i + (string)YELLOW "_" POP);

  } else {
    fon->draw(xpos, ypos, question + " "
	      BLUE + i + POP);
  }
}

void textinput::draw(int xp, int yp, int f) {
  draw_ch(xp, yp, f, 0);
}

/* XXX width should take into account
   potential length of input string, not just
   its current size */
void textinput::size(int & w, int & h) {
  /* space and cursor */
  w = fon->sizex(question + " _" + input);
  h = fon->height;
}

inputresult textinput::key(SDL_Event e) {
  
  int key = e.key.keysym.sym;

  /* finish immediately on enter if flag set */
  if (( // e.key.keysym.sym == SDLK_ENTER ||
       e.key.keysym.sym == SDLK_RETURN) &&
      accept_on_enter) return inputresult(MR_OK);

  inputresult def = menuitem::key(e);
  switch(def.kind()) {
  default: return def;
  case MR_NOTHING:

    switch(key) {
    case SDLK_BACKSPACE:
      input = input.substr(0, input.length() - 1);
      return inputresult(MR_UPDATED);
      break;

    default:
      if (e.key.keysym.sym == SDLK_u &&
	  e.key.keysym.mod & KMOD_CTRL) {
	 
	input = "";
	return inputresult(MR_UPDATED);

      } else {
	int uc = e.key.keysym.unicode;
	if ((uc & ~0x7F) == 0 && uc >= ' ') {
	  input += (char)(uc);
	  return inputresult(MR_UPDATED);
	} else return inputresult(MR_NOTHING);
      }
    } /* switch if unhandled */

  } /* switch on default */

}

/* only accept 'return' */
inputresult okay::key(SDL_Event e) {

  int key = e.key.keysym.sym;

  switch(key) {
  case SDLK_RETURN:
    activate();
    return inputresult(MR_OK);
  default: return menuitem::key(e);
  }

}

static void drawbutton(int x, int y, int w, int h, int f) {

  SDL_Rect r;
  r.x = x;
  r.y = y;
  r.w = w + 4;
  r.h = h + 2;
  SDL_FillRect(screen, &r,
	       SDL_MapRGBA(screen->format,
			   0x60 + (!!f * 0x20), 0x60 + (!!f * 0x20), 
			   0x60, 0xFF));
  
  /* draw bevel */
  r.h = 1;
  SDL_FillRect(screen, &r,
	       SDL_MapRGBA(screen->format,
			   0xA0, 0xA0, 0xA0, 0xFF));

  /* bottom */
  r.y += h + 2;
  SDL_FillRect(screen, &r,
	       SDL_MapRGBA(screen->format,
			   0x20, 0x20, 0x20, 0xFF));

  /* left */
  r.y -= (h + 2);
  r.x = x - 1;
  r.h = h + 2;
  r.w = 1;
  SDL_FillRect(screen, &r,
	       SDL_MapRGBA(screen->format,
			   0xA0, 0xA0, 0xA0, 0xFF));
  
  /* right */
  r.x += w + 5;
  r.h ++;
  SDL_FillRect(screen, &r,
	       SDL_MapRGBA(screen->format,
			   0x20, 0x20, 0x20, 0xFF));

}

/* XXX disabled? */
void okay::draw(int x, int y, int f) {

  drawbutton(x, y + 1, fon->sizex(text), fon->height, f);

  if (f) {
    fon->draw(x + 2, y + 2, YELLOW + text + POP);
  } else {
    fon->draw(x + 2, y + 2, text);
  }
}

void okay::size(int & w, int & h) {
  w = fon->sizex(text) + 4;
  h = fon->height + 4;
}



inputresult cancel::key(SDL_Event e) {

  int key = e.key.keysym.sym;

  switch(key) {
  case SDLK_RETURN:
    return inputresult(MR_CANCEL);
  default: return menuitem::key(e);
  }

}

/* XXX disabled? */
void cancel::draw(int x, int y, int f) {
  drawbutton(x, y + 1, fon->sizex(text), fon->height, f);

  if (f) {
    fon->draw(x + 2, y + 2, YELLOW + text + POP);
  } else {
    fon->draw(x + 2, y + 2, text);
  }
}

void cancel::size(int & w, int & h) {
  w = fon->sizex(text) + 4;
  h = fon->height + 4;
}


/* default keys for menuitems:
   up, tab, down, return, escape
*/
inputresult menuitem::key(SDL_Event e) {

  int key = e.key.keysym.sym;

  if (!(e.key.keysym.mod & (KMOD_CTRL | KMOD_ALT))) {
    switch(key) {
    case SDLK_UP:
      return inputresult(MR_PREV);

    case SDLK_TAB:
    case SDLK_DOWN:
    case SDLK_RETURN:
      return inputresult(MR_NEXT);

    case SDLK_ESCAPE:
      return inputresult(MR_CANCEL);

    default:
      /* ignore most keys */
      return inputresult(MR_NOTHING);
    }
  } else return inputresult(MR_NOTHING);
}

/* doesn't reclaim menuitems */
void menu::destroy() {
  if (alpharect) SDL_FreeSurface(alpharect);
  free(items);
  delete this;
}

menu * menu::create(drawable * be,
		    string ti,
		    ptrlist<menuitem> * its,
		    bool fs) {
  menu * m = new menu();
  if (!m) return m;
  m->title = ti;
  m->below = be;
  m->fullscreen = fs;

  m->alpha = 200;
  m->alpharect = 0;
  m->nitems = its->length();
  if (!m->nitems) {
    delete m;
    return 0;
  }
  m->items = (menuitem**)malloc(m->nitems *
				sizeof(menuitem *));
  
  if (!m->items) {
    delete m;
    return 0;
  }

  ptrlist<menuitem> * tmp = its;
  for(int i = 0; i < m->nitems; i ++) {
    m->items[i] = tmp->head;
    m->items[i]->container = m;
    tmp = tmp -> next;
  }

  return m;
}

void menu::draw() {

  if (below) below->draw();
  else {
    sdlutil::clearsurface(screen, BGCOLOR);
  }

  {
    SDL_Rect dest;
    
    dest.x = posx;
    dest.y = posy;
    
    SDL_BlitSurface(alpharect, 0, screen, &dest);
  }

  int x = posx + fon->sizex("*");

  /* current y offset (from posy) */
  int yoff = 4;

  fon->draw(x, posy + yoff, title); 
  yoff += fon->height;
  /* skip a line */
  yoff += fon->height;

  /* ensure the selected control is on the screen! */
  fixup( (h - (stath + fon->height)) - yoff );

  if (skip != 0) {
    fon->draw(x, 2 + posy + (yoff - fon->height), ALPHA50 PICS ARROWU POP YELLOW " More " POP PICS ARROWU POP POP);
  }

  /* XXX the calculations in the following two parts are shared,
     and it's annoying that they have to be maintained in parallel 
     (they are also used in clickselect, ugh) */

  /* first pass: find the location of the selected control
     and paint the background there. (We can't do this on
     the fly because the highlight partially overlaps the control
     above and below) */
  { 
    int yo = yoff;
    for (int n = skip; n < nitems; n++) {
      int iw, ih;
      items[n]->size(iw, ih); iw += items[n]->indent;
      /* give a line of leeway between control area and status area */
      if (yo + ih < (h - (stath + fon->height))) {
	/* room for this control */

	/* highlight the entire area if it is focused */
	if (n == selected) {
	  Uint32 color = SDL_MapRGBA(alpharect->format, 145, 120, 120, 255);
    
	  SDL_Rect dst;
	  dst.x = posx + 4;
	  dst.y = posy + yo - 1;
	  dst.h = ih + 2;
	  dst.w = w - 8;
	  SDL_FillRect(screen, &dst, color);
	  break; /* done */
	}

	yo += ih;

      } else {
	/* out of room for bg */
	printf("The selected control is off-screen! urgh (skip=%d, sel=%d)\n",
	       skip, selected);
	break;
      }
      
    }
  }

  /* now draw the controls */
  for (int n = skip; n < nitems; n++) {
    int iw, ih;
    items[n]->size(iw, ih); iw += items[n]->indent;
    /* give a line of leeway between control area and status area */
    if (yoff + ih < (h - (stath + fon->height))) {
      /* room for this control */

      items[n]->draw(x + items[n]->indent, posy + yoff, n == selected);

      yoff += ih;

    } else {
      /* out of space: stop trying to draw controls.
	 (but draw a "more" icon) */
      fon->draw(x, posy + yoff, ALPHA50 PICS ARROWD POP YELLOW " More " POP PICS ARROWD POP POP);
      break;
    }
  }

  /* now draw the status */
  yoff = (h - stath);
  
  fon->draw(x, posy + yoff, 
	    PICS BARLEFT BAR BAR BAR BAR BARRIGHT POP 
	    YELLOW " Help " POP
	    PICS BARLEFT BAR BAR BAR BAR BAR BAR BAR BAR BAR BAR BARRIGHT POP);
  yoff += fon->height;
  /* XXX need a way to draw this in a subtler color */
  yoff += fon->drawlines(x, posy + yoff, items[selected]->explanation);
  fon->draw(x, posy + h - (fon->height + 2),
	    GREY + items[selected]->helptext() + POP);

}


/* check if the current value of 'skip' places
   the control on-screen for the given vspace
   (height of control area) */
bool menu::skip_ok(int vspace) {
  /*
    if the control itself is bigger than the screen, we can't fit it at all,
    but this is still the best possible skip
  */
  if (skip == selected) return true;
  if (skip > selected) return false;

  /* ch represents the total height
     displaying all the controls between
     skip and z. We always have a title
     and separator */
  int ch = 0;
  for(int z = skip; z < nitems;) {
    int ww, hh;
    items[z]->size(ww, hh);

    ch += hh;

    if (ch <= vspace) {
      /* this control fits. If it's our
	 selected control then we're done. */
      if (z == selected) return true;
      z ++;
    } else 
      /* ran out of space; fail */
      return false;
  }

  /* ??? selected >= nitems or skip >= nitems? */
  return true;
}

/* XXX should try to keep at least one control above 
   and below visible */
/* set skip according to the amount of space
   available for controls (vspace) and the 
   currently selected control. */
void menu::fixup(int vspace) {

  /* no preposterous skips */
  if (skip < 0 || skip >= nitems) skip = 0;

  /* don't do anything if the skip is okay as-is */
  if (skip_ok(vspace)) return;

  /* 
     otherwise, find the minimum skip such that 
     the skip is "ok."

     start with skip = 0.
     if the focused element isn't on the screen,
     increment skip and try again until it is. 

     this algorithm is fine as long as there aren't a LOT
     of controls (thousands), but what kind of menu has
     thousands of controls?!
  */

  for(skip = 0; skip < nitems; skip ++)
    if (skip_ok(vspace)) return;
}

void menu::redraw() {
  draw();
  SDL_Flip(screen);  
}

/* sets up the sizes (w,h,stath,posx,posy,alpharect)
   after the screen has been resized, or when first
   creating the menu */
void menu::screenresize() {

  if (below) below->screenresize();

  /* calculate size of menu */

  /* toth is the size of the 'top half'
     of the menu (up to the help separator)
     need enough at least for the title,
     skipped lines before and after the control
     area, and a little margin.
  */
  int toth = 4 + fon->height * 3;
  /* maximum width of any control,
     help message, or line
     within an explanation */
  int maxw = 0;
  /* maximum number of lines in
     any explanation */
  int maxl = 0;

  for(int i = 0; i < nitems; i ++) {
    int tw, th;
    items[i]->size(tw, th); tw += items[i]->indent;
    toth += th;
    maxw =
      util::maximum(maxw, tw);

    maxw =
      util::maximum(maxw, 
		    fon->sizex(items[i]->helptext()));
    
    string ex = items[i]->explanation;
    
    int thisl = 0;
    while (ex != "") {
      string hi = util::chopto('\n', ex);
      maxw =
	util::maximum(maxw, fon->sizex(hi));
      thisl ++;
    }

    maxl =
      util::maximum(maxl, thisl);

  }

  /* need room at least for the separator,
     and help line */
  maxl += 2;

  /* first cuts: try to fit everything
     with a bit of margin on the left
     and right */
  w = maxw + fon->sizex("**");
  /* room for lines at the bottom, plus margin */
  stath = maxl * fon->height + 4;
  h = toth + stath + 1;

  /*
  printf("h: %d\n"
	 "stath: %d\n"
	 "toth: %d\n"
	 "maxl: %d\n", 
	 h, stath, toth, maxl);
  */

  /* if the result is too wide, shrink it
     a bit. This is bad since we don't
     have any way to shrink the controls to fit. */

  int mw = screen->w - fon->sizex("**");
  if (w > mw) w = mw;

  /* ditto for the height. At least here
     we will be able to fit things by displaying
     only some chunk of the controls at any
     given time. */

  int mh = screen->h - fon->sizex("******");
  if (h > mh) h = mh;

  /* no matter what, center it on the screen */
  posx = (screen->w - w) / 2;
  
  /* maybe center vertically */
  if (yoffset <= 0) {
    posy = (screen->h - h) / 2;
  } else {
    posy = yoffset;
  }

  /* resize background rectangle */
  if (alpharect) SDL_FreeSurface(alpharect);
  // alpharect = sdlutil::makealpharect(w, h, 90, 90, 90, alpha /* 180 */);
  alpharect = sdlutil::makealpharectgrad(w, h, 
					 120, 120, 120, alpha,
					 70, 70, 70, alpha);

  /* draw title bar */
  {
    Uint32 color = SDL_MapRGBA(alpharect->format, 
			       120, 120, 145, alpha /* 200 */);
    
    SDL_Rect dst;
    dst.x = 0;
    dst.y = 0;
    dst.h = fon->height + 4;
    dst.w = w;
    SDL_FillRect(alpharect, &dst, color);
  }
  /* draw line separating title bar from rest */
  {
    Uint32 color = SDL_MapRGBA(alpharect->format, 
			       50, 50, 80, alpha /* 200 */);
    
    SDL_Rect dst;
    dst.x = 0;
    dst.y = fon->height + 4;
    dst.h = 2;
    dst.w = w;
    SDL_FillRect(alpharect, &dst, color);
  }
  /* draw the status (help) bar area */
  {
    Uint32 color = SDL_MapRGBA(alpharect->format, 
			       32, 32, 32, alpha /* 200 */);
    
    SDL_Rect dst;
    dst.x = 0;
    dst.y = h - (fon->height + 2);
    dst.h = fon->height + 2;
    dst.w = w;
    SDL_FillRect(alpharect, &dst, color);
  }
  {
    Uint32 color = SDL_MapRGBA(alpharect->format, 
			       36, 36, 36, alpha /* 200 */);
    
    SDL_Rect dst;
    dst.x = 0;
    dst.y = h - (fon->height + 4);
    dst.h = 2;
    dst.w = w;
    SDL_FillRect(alpharect, &dst, color);
  }

  /* finally, make the entire help area darker */
  {
    Uint32 color = SDL_MapRGBA(alpharect->format, 
			       65, 65, 65, alpha /* 180 */);
    
    int fonthalf = fon->height >> 1;
    SDL_Rect dst;
    dst.x = 0;
    dst.y = fonthalf + h - stath;
    dst.h = stath - (fon->height + 4 + fonthalf);
    dst.w = w;
    SDL_FillRect(alpharect, &dst, color);
  }

  /* outline the whole thing */
  sdlutil::outline(alpharect, 2, 36, 36, 36, alpha /* 200 */);

}

/* XXX loops forever if no focusable */
void menu::nextfocus(int d) {
  for(;;) {
    if (items[selected]->focusable()) return;
    selected += d;
    if (selected < 0) selected = nitems - 1;
    if (selected >= nitems) selected = 0;
  }
}

/* relative to menu */
inputresult menu::clickselect(int xc, int yc) {
  /* current y offset (from posy). start in the
     control area */
  int y = TOPBARHEIGHT;

  { 
    for (int n = skip; n < nitems; n++) {
      int iw, ih;
      items[n]->size(iw, ih); 
      iw += items[n]->indent;
      /* give a line of leeway between control area and status area */
      if (y + ih < (h - (stath + fon->height))) {
	/* this control will be on screen, so did we
	   click it? */

	if ((!items[n]->disabled) &&
	    xc >= 0 &&
	    xc < w &&
	    yc >= y &&
	    yc <= (y + ih)) {
	  
	  /* at a minimum, select this one if it is
	     focusable */
	  if (items[n]->focusable()) selected = n;
	  inputresult res = items[n]->click(xc, yc - y);
	  redraw();
	  return res;
	}

	y += ih;

      } 
      
    }
  }
  return inputresult(MR_REJECT);
}

#define PROCESSRESULT(res)              \
  switch(res.kind()) {                  \
  case MR_OK:                           \
  case MR_CANCEL:                       \
  case MR_QUIT: return res.kind();      \
	                                \
  case MR_UPDATED:                      \
    redraw();                           \
    break;                              \
  case MR_REJECT:                       \
    /* XXX beep or flash display */     \
    break;                              \
                                        \
  case MR_NEXT:                         \
    selected ++;                        \
    selected %= nitems;                 \
    nextfocus(1);                       \
    redraw();                           \
    break;                              \
                                        \
  case MR_PREV:                         \
    if (!selected) {                    \
      selected = nitems - 1;            \
    } else --selected;                  \
    nextfocus(-1);                      \
    redraw();                           \
    break;                              \
                                        \
  default:                              \
  case MR_NOTHING:                      \
    break;                              \
  }

resultkind menu::menuize() {
  /* always start out at the beginning */
  selected = 0;
  nextfocus(1);
  screenresize();

  redraw();
  
  SDL_Event e;

  /* event loop */
  while (SDL_WaitEvent(&e) >= 0) {
    if (handle_video_event(this, e)) continue;

    switch(e.type) {
    case SDL_MOUSEBUTTONDOWN: {
      SDL_MouseButtonEvent * em = (SDL_MouseButtonEvent*)&e;

      if (em->button == SDL_BUTTON_LEFT) {
	/* are we clicking on a menu item? */
	
	int x = em->x;
	int y = em->y;

	if (x >= posx &&
	    x < (posx + w)) {

	  if (y >= (posy + TOPBARHEIGHT) &&
	      y < (posy + h)) {
	    
	    inputresult res = 
	      clickselect(x - posx, y - posy);
	    PROCESSRESULT(res);
	  } else if (y >= posy && 
		     y <= (posy + TOPBARHEIGHT)) {
	    /* click in topbar */

	    int sx = x;
	    int sy = y;
	    int opx = posx;
	    int opy = posy;
	    // printf("DRAGMODE\n");

	    /* DRAG mouse capture */
	    SDL_Event event;

	    for (;;) while ( SDL_PollEvent(&event) ) {
	      
	      switch(event.type) {
	      case SDL_MOUSEMOTION: {
		SDL_MouseMotionEvent * e = (SDL_MouseMotionEvent*)&event;

		// printf("DRAGMODE %d %d\n", e->x, e->y);		
		posx = opx + (e->x - sx);
		posy = opy + (e->y - sy);

		/* but snap to screen */
		if (posx < 0) posx = 0;
		if (posy < 0) posy = 0;

		/* XXX also bottom and right? */

		redraw();
		/* PERF dump events that are queued up? */
		break;
	      }
	      case SDL_MOUSEBUTTONUP:
		if (em->button == SDL_BUTTON_LEFT) goto dragdone;
		break;
	      }
	      
	    }

	  dragdone:
	    redraw();
	  }
	}
      }
    }
      break;
    case SDL_QUIT:
      return MR_QUIT;
    case SDL_KEYDOWN: {

      inputresult res = items[selected]->key(e);
      PROCESSRESULT(res);
      break;
    }
    default:;
    }
  }
  /* XXX possible? what does waitevent < 0 mean? */
  return MR_CANCEL;
}
