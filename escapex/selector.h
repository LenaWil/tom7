
#ifndef __SELECTOR_H
#define __SELECTOR_H

#include <SDL.h>
#include "escapex.h"
#include "level.h"
#include "sdlutil.h"
#include "font.h"
#include "draw.h"

#define SELCOLOR 0xFF224422

#define DPRINTF if(0) printf

/* try to avoid startup events. ?? but how
   can we base this on time? */
#define SELECTOR_DEADTIME 0
// 1200

/* A selector creates a menu that can be navigated with the arrow keys
   (among others) to select something from the list. The items
   in the list are members of the Item class, and the Ret class is
   what is returned when the user presses enter.

   item :
     void swap(Item * l, Item * r)
      - destructive swap of the fields in l and r. used only if
      sort is called.

     bool matches (char k);
      - return true if the text can be said to 'match' the char k
        (when a key is pressed that doesn't do anything else, it
 	 jumps to the next matching entry).

     static Ret none();
      - when the user presses escape, this is returned. A typical
        value would be 0 when Ret is a pointer type. 

     static int height();
      - return the height of each item in pixels

     void draw(int x, int y, bool sel);
      - draw the option at the location x,y. If it is currently selected,
        the boolean 'sel' will be true.
     
     Ret convert();
      - convert this item into a returnable Ret, upon its selection.

     The Item class's destructor is used to deallocate it, rather
     than a destroy() method.

   ret :

     No required methods. Typically a pointer type.

*/

template <class Item, class Ret>
struct selector : public drawable {

  int botmargin;
  int yfit;
  int selected, skip;
  int number;

  drawable * below;

  /* SDL sends mousemotion events
     when there is no motion, sometimes--
     (like when the window is first opened). 
     This lets us ignore those.
  */
  int deadtime;

  string title;

  Item * items;

  void destroy () {
    delete [] items;
    delete this;
  }

  /* sorts the selector using the compare function.
     left < right     ->    -1
     left = right     ->     0
     left > right     ->     1 */
  void sort( int (*compare)(const Item & left, const Item & right) ) {
    quicks(compare, 0, number - 1);
  }

  /* do you know how hard it is to find a public domain
     quicksort routine that is actually correct? After
     several tries I just wrote my own: */

  /* sort items between first and last (inclusive) in the array. */
  void quicks(int (*compare)(const Item &, const Item &), 
	      int first, int last) {
    /* done for zero, negative, or one-sized arrays. */
    if ((last - first) <= 0) return;

    /* pick a pivot, and put it at position [first] */
    /* (right now just use whatever is already in 'first' */

    int i = first + 1;
    int j = last;

    /* invariant in while loop:
       everything from first+1 .. i-1 is less-eq than [first]
       everything from j + 1 .. last is greater than [first]. */
    
    /* move fingers together, preserving the invariant */
    while (i != j) {
      if (compare(items[i], items[first]) != 1) { /* <= */
	/* [i] belongs in less-eq set */
	i ++;
	continue;
      } else {
	/* [i] belongs on the other side */

	if (compare(items[j], items[first]) == 1) { /* > */
	  /* [j] belongs in greater set */
	  j --;
	  /* XXX could be more efficient by avoiding re-test
	     for i; favor simplicity now */
	  continue;
	} else {
	  /* [j] belongs on the other side */
	  Item::swap(&items[i], &items[j]);
	  
	  /* the invariant still holds, and we have
	     made progress towards sorting, so we
	     can continue */
	  continue;
	}

      }

    }

    /* [piv] ... less-eq ... [i,j] ... greater ... */
    if (compare(items[i], items[first]) != 1) { /* <= */
      /* [i] <= [pivot]. if we swap them,
	 we'll be all set. */

      /* pivot is bigger than gap. swap them. */
      Item::swap(&items[first], &items[i]);
      /* these must be smaller */
      quicks(compare, first, i - 1);
      quicks(compare, i + 1, last);
    } else { /* [i] > [pivot] */
      /* [i] needs to be in the greater set.
	 however, we know [i - 1] is in the
	 smaller set. swap it with the pivot.
	 i - 1 is always at least as big as 
	 first because i starts at first + 1 
	 and only increases.
      */
      if (first != (i - 1)) Item::swap(&items[first], &items[i - 1]);
      
      /* adjust subslices. i isn't necessarily
	 the smallest thing in the greater set.
	 but the new pivot is bigger than anything
         in the lesseq set. */
      quicks(compare, first, i - 2);
      quicks(compare, i, last);
    } 
  }

  /* resize the items array. if growing, this
     leaves items at the tail end uninitialized.

     nb, shrinking can be done cheaply and safely
     by just decrementing 'number.'
  */
  void resize (int newsize) {
    Item * olditems = items;
    
    items = new Item[newsize];
  
    for(int i = 0; i < number; i ++) {
      items[i] = olditems[i];
    }
    
    delete [] olditems;
    number = newsize;
  }

  static selector * create(int n) {
    selector * s = new selector();
    s->number = n;
    s->items = new Item[n];
    s->skip = 0;
    s->selected = 0;

    s->botmargin = 80;
    s->below = 0;

    s->title = "Select using the arrow keys and press enter.";

    s->reset ();

    /* XXX check for fail of new Item[] */

    return s;
  }

  virtual void redraw () {
    draw();
    SDL_Flip(screen);
  }

  virtual void draw () {

    if (below) {
      below->draw();
    } else {
      /* clear back */
      sdlutil::clearsurface(screen, BGCOLOR);
    }

    int topsize = fon->drawlines(2, 1, title);

    /* set skip, if necessary */
    yfit = ((screen->h - (botmargin + topsize)) / Item::height());
    if (selected < skip) skip = selected - 4;
    if (selected >= (skip + yfit)) skip = (selected - (yfit - 4));
    if (skip > (number - yfit)) skip = (number - yfit);
    if (skip < 0) skip = 0;

    for(int i = skip; i < number && i < (skip+yfit); i++) {

      if (i == selected) {
	/* draw bar */
	SDL_Rect dst;
	dst.x = 6;
	dst.w = screen->w - 12;
	dst.y = 2 + topsize + (i - skip) * Item::height() - 1;
	dst.h = Item::height() + 2;
	SDL_FillRect(screen, &dst, SELCOLOR);
      }

      items[i].draw(8, 2 + topsize +
		    (i - skip) * Item::height(), (i==selected));
    }



  }

  /* Don't have to do anything because our size is specified in
     terms of the screen size. (Though maybe that's not ideal.)
     But give the parent a chance to rejigger. */
  virtual void screenresize() {
    below->screenresize();
  }

  bool pointitem(int y, int & n) {
    int topsize = fon->lines(title) * fon->height + 2;

    /* nb. it is possible to select an item that is out of the
       visible window with this, which causes scrolling. However,
       this is probably desirable because it provides a way to
       scroll with the mouse. */

    /* are we in the item area? */
    int my = y - topsize;
    if (y >= 0 && y < (screen->h - botmargin)) {
      int nth = (my / Item::height()) + skip;

      if (nth < 0 || nth >= number) return false;

      n = nth;
      return true;

    } else return false;
  }

  enum petype { PE_SELECTED, PE_CANCEL, PE_EXIT, PE_NONE, };

  struct peres {
    petype type;
    union {
      /* which was selected? */
      int i;
    } u;
    peres(petype t) : type(t) {}
    peres(int i) : type(PE_SELECTED) { u.i = i; }
  };

  peres doevent(SDL_Event e) {
    int key;
    DPRINTF("sel.h doevent %d\n", e.type);

    if (handle_video_event(this, e)) return peres(PE_NONE);

    switch(e.type) {
    /* new! mouse stuff */
    case SDL_MOUSEBUTTONDOWN: {
      DPRINTF("  ... mbd\n");
      SDL_MouseButtonEvent * em = (SDL_MouseButtonEvent*)&e;

      if (em->button == SDL_BUTTON_LEFT) {
	/* check that we are in zone */
	int x;
	if (pointitem(em->y, x)) return peres(x);
      }
      break;
    }
    case SDL_MOUSEMOTION: {
      SDL_MouseMotionEvent * em = (SDL_MouseMotionEvent*)&e;
      DPRINTF("  ... mm (%d, %d)\n", em->x, em->y);

      int nth;
      int now = SDL_GetTicks();

      if (now > deadtime) {
	/* in range! */
	if (pointitem(em->y, nth) && selected != nth) {
	  /* new selection! */
	  selected = nth;
	  redraw();
	}
      }

      break;
    }
    case SDL_QUIT:
      return peres(PE_EXIT);
    case SDL_KEYDOWN:
      DPRINTF("  ... kd\n");
      key = e.key.keysym.sym;

      /* don't allow bucky */
      if (!(e.key.keysym.mod & (KMOD_CTRL | KMOD_ALT)))
	switch(key) {
	case SDLK_ESCAPE:
	  return peres(PE_CANCEL);

	case SDLK_RETURN:
	  //	printf("Here: %s\n", -thisdir[selected].fname);
	  return peres(selected);

	case SDLK_HOME:
	case SDLK_END:
	case SDLK_PAGEDOWN:
	case SDLK_PAGEUP:
	case SDLK_DOWN:
	case SDLK_UP: {

	  switch(e.key.keysym.sym) {
	  case SDLK_DOWN: selected ++; break;
	  case SDLK_UP: selected --; break;
	  case SDLK_PAGEUP: selected -= yfit; break; 
	  case SDLK_PAGEDOWN: selected += yfit; break;
	  case SDLK_HOME: selected = 0; break;
	  case SDLK_END: selected = number - 1; break;
	  default: ; /* lint - impossible */
	  }
      
	  /* XXX wrap around? (pref?) */
	  if (selected >= number) selected = number - 1;
	  if (selected < 0) selected = 0;

	  redraw();

	  break;
	}
	default:
	  if (key >= SDLK_a &&
	      key <= SDLK_z) {

	    /* use lowercase */
	    char k = 'a' + (key - SDLK_a);
	    
	    for(int i = 1; i < number; i ++) {
	      if (items[(selected + i) % number].matches(k)){
		selected = (selected + i) % number;
		break;
	      }
	    }

	    redraw ();
	  }
	}
      break;
    default: 
      DPRINTF(" other!\n");
      break;
    }
    return peres(PE_NONE);
  }

  void reset () {
    deadtime = SDL_GetTicks() + SELECTOR_DEADTIME;
  }

  Ret loop()  {
    redraw();

    SDL_Event event;

    reset ();

    while ( SDL_WaitEvent(&event) >= 0 ) {

      peres pr = doevent(event);
      switch(pr.type) {
      case PE_SELECTED:
	return items[pr.u.i].convert();
      case PE_EXIT: /* XXX */
      case PE_CANCEL:
	return Item::none();
      default:
      case PE_NONE:
	;
      }
    }

    return Item::none();
  }

};

#endif
