
#include "SDL.h"
#include "SDL_image.h"
#include <math.h>
#include "level.h"
#include "sdlutil.h"
#include "draw.h"

#include "escapex.h"
#include "play.h"
#include "prompt.h"

#include "extent.h"
#include "util.h"
#include "edit.h"

#include "load.h"
#include "md5.h"

#include "message.h"
#include "menu.h"

enum { PF_NONE = 0, PF_TIMER, PF_FILE, };

/* move him out of the selection */
bool editor::moveplayersafe() {
  if (dr.lev->guyx >= selection.x &&
      dr.lev->guyy >= selection.y &&
      dr.lev->guyx < (selection.x + selection.w) &&
      dr.lev->guyy < (selection.y + selection.h)) {
    for(int y = 0; y < dr.lev->h; y++)
      for(int x = 0; x < dr.lev->w; x++) {
	if (x >= selection.x &&
	    y >= selection.y &&
	    x < (selection.x + selection.w) &&
	    y < (selection.y + selection.h)) continue;
	
	if (dr.lev->botat(x, y)) continue;

	dr.lev->guyx = x;
	dr.lev->guyy = y;

	return true;
      }
    return false;
  } else return true;
}

void editor::prefab() {
  if (selection.w) {
    /* display menu to select. */
    int what = 0;

    label message;
    message.text = 
      PICS QICON POP
      " Select a prefab to insert.";

    vspace spacer(fon->height);
	      
    okay timer("Timer", &what, PF_TIMER);
    timer.explanation = "Insert a bot-based countdown timer\n"
                        "for a specified number of moves.";
	      
    okay file("File", &what, PF_FILE);
    file.explanation = "Paste the contents of another level\n"
                       "in a file you choose.";

    cancel can;
    can.text = "Cancel";
	      
    ptrlist<menuitem> * l = 0;
	      
    ptrlist<menuitem>::push(l, &can);
    ptrlist<menuitem>::push(l, &spacer);

    ptrlist<menuitem>::push(l, &file);
    ptrlist<menuitem>::push(l, &timer);
    ptrlist<menuitem>::push(l, &spacer);
	      
    ptrlist<menuitem>::push(l, &message);
	      
    /* display menu */
    menu * mm = menu::create(this, "Which prefab?", l, false);
    resultkind res = mm->menuize();
    ptrlist<menuitem>::diminish(l);
    mm->destroy ();
	      
    if (res == MR_OK) {
      switch (what) {
      case PF_TIMER:
	if (!moveplayersafe()) {
	  message::no(this, "There's nowhere to put the player!");
	} else {
	  pftimer();
	}
	break;
      case PF_FILE:
	pffile();
	break;
      default:;
	message::bug(this, "no prefab was selected..??");
      }
    }
  } else {
    message::no(this, "You must select a region first.\n"
		"   " GREY "(drag with the right mouse button held)" POP);
  }
  redraw();
}


/* XXX should allow me to specify the prompt for loading */
void editor::pffile() {
  level * small;
  {
    loadlevel * ll = loadlevel::create(plr, EDIT_DIR, true, true);
    if (!ll) {
      message::quick(this, "Can't open load screen!", 
		     "Ut oh.", "", PICS XICON POP);
      redraw ();
      return ;
    }
    string res = ll->selectlevel();
    string ss = readfile(res);
    ll->destroy ();
    
    /* allow corrupted files */
    small = level::fromstring(ss, true);
  }

  if (!small) { 
    dr.message = ((string) RED "error loading file to place" POP);
    return;
  }

  /* now menu */
  /* XXX should show preview of level we're about to place */
  label message;
  message.text = 
    PICS QICON POP
    " "   "This will place the level " BLUE + small->title + POP;
  label message2;
  message2.text =
    "   " "within the selected region.";

  vspace spacer(fon->height);

  okay ok("OK");

  cancel can;
  can.text = "Cancel";

  textinput xoff;
  xoff.explanation = "Ignore this many columns in the input.";
  xoff.question = "X offset: ";
  xoff.input = "0";
  textinput yoff;
  yoff.explanation = "Ignore this many rows in the input.";
  yoff.question = "Y offset: ";
  yoff.input = "0";
     
  /* XXX (don't) constrain to selection option? */


  ptrlist<menuitem> * l = 0;
	      
  ptrlist<menuitem>::push(l, &can);
  ptrlist<menuitem>::push(l, &ok);
  ptrlist<menuitem>::push(l, &spacer);
  
  ptrlist<menuitem>::push(l, &yoff);
  ptrlist<menuitem>::push(l, &xoff);

  ptrlist<menuitem>::push(l, &message2);
  ptrlist<menuitem>::push(l, &message);
	      
  /* display menu */
  menu * mm = menu::create(this, "Inserting file", l, false);
  resultkind res = mm->menuize();
  ptrlist<menuitem>::diminish(l);
  mm->destroy ();
	      
  if (res == MR_OK) {
    int xo = stoi(xoff.input);
    int yo = stoi(yoff.input);
    if (xo < 0 || yo < 0) {
      message::no(this, "bad offsets");
      return;
    }

    /* remove existing bots/player in selection */
    {
      moveplayersafe();
      for(int x = selection.x; x < selection.x + selection.w; x++)
	for(int y = selection.y; y < selection.y + selection.h; y ++)
	  clearbot(x, y);
    }


    /* tiles and dests */
    for(int y = 0; y < small->h; y ++)
      for(int x = 0; x < small->w; x ++) {
	
	int srcx = x + xo;
	int srcy = y + yo;
	int dstx = x + selection.x;
	int dsty = y + selection.y;

	/* has to be in both source and destination. */
	if (srcx >= 0 && srcx < small->w &&
	    srcy >= 0 && srcy < small->h &&

	    dstx >= selection.x && dstx < selection.x + selection.w &&
	    dsty >= selection.y && dsty < selection.y + selection.h
	    
	    /*
	      or for no cropping...
	    dstx >= 0 && dstx < dr.lev->w &&
	    dsty >= 0 && dsty < dr.lev->h
	    */
	    ) {
	  
	  dr.lev->settile(dstx, dsty,
			  small->tileat(srcx, srcy));
	  dr.lev->osettile(dstx, dsty,
			    small->otileat(srcx, srcy));
	  if (level::needsdest(dr.lev->tileat(dstx, dsty)) ||
	      level::needsdest(dr.lev->otileat(dstx, dsty))) {
	    
	    int sdx, sdy;
	    small->getdest(srcx, srcy, sdx, sdy);
	    sdx += (dstx - srcx);
	    sdy += (dsty - srcy);
	    /* then make sure it's in bounds... */
	    if (sdx < 0) sdx = 0;
	    if (sdx >= dr.lev->w) sdx = dr.lev->w - 1;
	    if (sdy < 0) sdy = 0;
	    if (sdy >= dr.lev->w) sdy = dr.lev->w - 1;
	    dr.lev->setdest(dstx, dsty, sdx, sdy);
	  }
	}

      }

    /* bots */
    for(int i = 0; i < small->nbots; i ++) {
      int xx, yy;
      small->where(small->boti[i], xx, yy);

      xx += selection.x - xo;
      yy += selection.y - yo;
      if (xx >= selection.x && yy >= selection.y &&
	  xx < selection.x + selection.w && 
	  yy < selection.y + selection.h) {
	if (dr.lev->nbots < LEVEL_MAX_ROBOTS)
	  this->addbot(xx, yy, small->bott[i]);
      }
    }

    /* definitely need to fix up (canonicalize bot order
       especially) */
    fixup();

  }
 
  redraw();
}

/* checks the condition at time t, for pftimer below */
static bool timer_check(int * M, int * A, int i, int t) {
  for(int z = 0; z < i; z ++) {
    if (((A[z] + t) % M[z]) != 0) return false;
  }
  return true;
}

/* insert a timer. Prompt for the number of moves, then try to use
   the minimum number of bots within the given space to form the
   timer. */
void editor::pftimer() {
  label message;
  message.text = 
    PICS QICON POP
    " " RED "Note:" POP " Please use timers in good taste; leave a";
  label message2;
  message2.text =
    "   " "little slack for the player!";

  vspace spacer(fon->height);
	      
  okay ok("OK");
  
  cancel can;
  can.text = "Cancel";
	      
  textinput nmoves;
  nmoves.explanation = "The player will have this many moves\n"
    "before the bot reaches the stop sign.";
  nmoves.question = "Number of moves: ";

  /* XX could check automatically based on location of selection */
  toggle reverse;
  reverse.question = "Player on left";
  reverse.explanation = "The timer must be on either the left side\n"
                        "or right side of the level. Check this to\n"
                        "put it on the right side (with the player)\n"
                        "on the left.";
  reverse.checked = false;

  ptrlist<menuitem> * l = 0;
	      
  ptrlist<menuitem>::push(l, &can);
  ptrlist<menuitem>::push(l, &ok);
  ptrlist<menuitem>::push(l, &spacer);
  
  ptrlist<menuitem>::push(l, &reverse);
  ptrlist<menuitem>::push(l, &nmoves);

  ptrlist<menuitem>::push(l, &message2);
  ptrlist<menuitem>::push(l, &message);
	      
  /* display menu */
  menu * mm = menu::create(this, "Inserting timer", l, false);
  resultkind res = mm->menuize();
  ptrlist<menuitem>::diminish(l);
  mm->destroy ();
	      
  if (res == MR_OK) {
    int n = stoi(nmoves.input);
    if (n <= 0) {
      message::no(this, "bad number of moves");
      return;
    }
    
    /* the general idea here is to form a series of rows, each
       containing a dalek that walks left and into a transporter that
       resets him to his "home" position (offset 0). the length of
       this cycle is M_i, the modulus.

       each bot starts at an offset from the home position, which is
       A_i.

       in the home position there is a panel that targets a series
       of transporters for the trigger bot. These transporters all
       target the trigger bot's home position (offset 0), such that
       the trigger bot can only reach the end of his row at time t,
       where t is the least such time where
       (A_i + t) mod M_i = 0
       for every i.
	 
       The problem, then, is to compute the best i, M_i, and A_i,
       subject to the following constraints:

       i < MAX_BOTS - existing_bots      (1 is needed for the 
       trigger bot as well)
       i < selection.h - 2               (3 rows for trigger bot)
       max(M_i) < selection.w            (1 needed for teleport)
       
       We want to minimize the solution, according to the following
       measure (lexicographically),
         - smallest i
         - smallest max(M_i)
    */

    /* There's of course a much faster way to do this, using the Chinese
       Remainder Theorem. But given how small the values of t that we'll
       encounter will be, looping makes it easier to make sure we get it
       right. */
    
    int M[LEVEL_MAX_WIDTH];
    int A[LEVEL_MAX_WIDTH];

    for(int i = 1; (i < LEVEL_MAX_ROBOTS - dr.lev->nbots) && 
	            i < (selection.w - 2) &&
	            i < (selection.h - 2); i++) {
      if (timer_try(M, A, 0, i, n, reverse.checked)) return;
    }

    message::no(this, "Can't find a timer; try increasing the width,\n"
		"   " "height, and number of available bots.");

  }
}

/* compute all timers of length i where
   M[x],A[x] are fixed for 0<=x<j.
   if successful, modify the level to insert
   the timer and then return true.
*/
bool editor::timer_try(int * M, int * A, int j, int i, int n, bool rev) {

  if (j < 0 || j > i) abort();

  if (j < i) {
    /* wlog we will assume that M_i > M_i+1, also
       M_i of 0 ill-defined, and 1 pointless, 
       so start at 2. */
    
    for(M[j] = 2; M[j] < (j?M[j-1]:selection.w); M[j]++) {
      for(A[j] = 0; A[j] < M[j]; A[j]++) {
	if (timer_try(M, A, j + 1, i, n, rev)) return true;
      }
    }

    return false;
  } else {

    /* must be correct at time t */
    if (!timer_check(M, A, i, n)) return false;

    /* also must not be satisfied for any smaller t */
    {
      for(int u = 0; u < n; u++) {
	if (timer_check(M, A, i, u)) return false;
      }
    }

    /* good! */
    #if 0
    printf("okay: i=%d\n", i);
    {
      for(int z = 0; z < i; z ++) {
	printf("  M[%d] = %d, A[%d] = %d\n",
	       z, M[z], z, A[z]);
      }
    }
    #endif
    /* write it... */

    /* black out selection */
    {
      for(int x = selection.x; x < selection.x + selection.w; x++) {
	for(int y = selection.y; y < selection.y + selection.h; y ++) {
	  dr.lev->settile(x, y, T_BLACK);
	  clearbot(x, y);
	}
      }
    }

    // printf("cleared..\n");

    int dx = rev?-1:1;

    int rootx = rev?(selection.x + selection.w - 1):selection.x;

    /* XXX could do better on trigger bot; only need
       to block it on top and bottom at the first column. 
       (usually this cell is not used above because M[j] is
       strictly decreasing. */
    {
      int trigx = rootx + (dx * selection.w) - (dx * (i + 2));
      int trigy = i + 1;

      /* set up bot for trigger */
      addbot(trigx, trigy, B_DALEK);
      dr.lev->settile(trigx + dx * (i + 1), trigy, T_RPANEL);
      /* target self, I guess? */
      dr.lev->setdest(trigx + dx * (i + 1), trigy, 
		      trigx + dx * (i + 1), trigy);

      for(int z = 0; z < i; z ++) {
	int home = (rootx + dx * (selection.w - 1)) - (dx * M[z]);

	#if 0
	printf("home: %d\n", home);
	printf(" set %d/%d\n", selection.x + selection.w - 1,
	       selection.y + z);
	#endif

	int y = selection.y + z;

	/* clear a path */
	for(int x = home; x != rootx + dx * selection.w; x += dx) {
	  dr.lev->settile(x, y, T_ROUGH);
	}

	/* teleporter at far right. */
	dr.lev->settile(rootx + dx * (selection.w - 1), y, T_TRANSPORT);
	dr.lev->setdest(rootx + dx * (selection.w - 1), y,
			home, y);

	/* make panel */
	dr.lev->settile(home, y, T_PANEL);
	dr.lev->setdest(home, y, trigx + dx * (1 + z), trigy);

	dr.lev->settile(trigx + dx * (1 + z), trigy, T_BLACK);
	dr.lev->osettile(trigx + dx * (1 + z), trigy, T_RSTEEL);
	/* do a pre-emptive swap if bot starts home, since he'll be
	   on the panel */
	if (A[z] == 0) dr.lev->swapo(dr.lev->index(trigx + dx * (1 + z), trigy));

	if (dr.lev->nbots >= LEVEL_MAX_ROBOTS) {
	  message::bug(this, "oops, exceeded bots! bug!");
	  return true;
	}

	addbot(home + dx * A[z], y, B_DALEK);

      }
    }

    changed = 1;
    return true;
  }
}
