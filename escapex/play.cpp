
#include "SDL.h"
#include "SDL_image.h"
#include <math.h>
#include "time.h"
#include "level.h"
#include "sdlutil.h"
#include "draw.h"

#include "escapex.h"
#include "play.h"

#include "extent.h"
#include "message.h"
#include "chars.h"
#include "util.h"
#include "dirindex.h"
#include "md5.h"
#include "prefs.h"
#include "prompt.h"

#include "aevent.h"
#include "animation.h"
#include "dirt.h"
#include "optimize.h"

#include "menu.h"
#include "smanage.h"
#include "client.h"
#include "base64.h"

#define POSTDRAW ;

/* for observing frame by frame -- slooow */
// #define POSTDRAW SDL_Delay (300);

/* medium speed */
// #define POSTDRAW SDL_Delay (100);

struct bookmarkitem;

enum playstate {
  STATE_OKAY,
  STATE_DEAD,
  STATE_WON,
};

struct preal : public play {

  bool waitenter();
  virtual void draw ();
  virtual void screenresize();

  virtual playresult doplay_save(player *, level *, 
				 solution *& saved, string md5 = "");

  virtual ~preal ();

  /* debugging */
  int layer;
  bool showdests;
  bool showdestsshuffle;
  bool showbotnums;

  drawing dr;
  /* current solution.
     Its lifetime is within a call to doplay_save.
     Don't call redraw when not inside a call to doplay_save! */
  solution * sol;
  /* current position in the
     solution. This is usually the same as sol->length, but
     if it is not, then we support the VCR (soon) and redo. */
  int solpos;

  static preal * create();
  void redraw ();

  void videoresize(SDL_ResizeEvent * eventp);

  virtual void destroy() {
    delete this;
  }

  /* hand closure-converted, ugh */
  bool redo();
  void undo(level *& start, extent<level> & ec, int nmoves);
  void restart(level *& start, extent<level> & ec);
  void checkpoint(solution *& saved_sol,
		  extent<solution> & ess);
  void restore(extent<level> & ec,
	       level * start,
	       solution * saved_sol,
	       extent<solution> & eso);
  void bookmarks(level * start, 
		 extent<level> & ec,
		 player * plr, string md5, 
		 solution *& sol,
		 extent<solution> & eso);
  void bookmark_download(player * plr, string lmd5, level * lev);


  void drawmenu();

private:
  bool getevent(SDL_Event * e, bool & fake);

  bool watching;
  Uint32 nextframe;
  playstate curstate();

  static void setsolseta(player * plr, string md5,
			 bookmarkitem ** books,
			 int n);
};

play::~play () {}
preal::~preal () {}

play * play::create () {
  return preal::create();
}

preal * preal::create() {
  preal * pr = new preal();
  pr->watching = false;
  pr->layer = 0;
  pr->showdests = false;
  pr->showdestsshuffle = false;
  pr->showbotnums = false;
  pr->dr.margin = 12;
  return pr;
}

SDL_Event dummy[256];

/* idea: scrolling move history? */
#define MI_NODRAW -1
int play_menuitem[] = {
  TU_SAVESTATE,
  TU_RESTORESTATE,
  TU_BOOKMARKS,
  /* TU_QUIT */
  TU_RESTART,
  TU_UNDO,
  TU_REDO,
  TU_FUNDO,
  TU_PLAYPAUSE,
  TU_FREDO,
  0, MI_NODRAW, /* skip -- nmoves */
};

#define POS_RESTORESTATE 1
#define POS_RESTART 3
#define POS_UNDO 4
#define POS_REDO 5
#define POS_MOVECOUNTER 9
#define POS_PLAYPAUSE 7
#define POS_FUNDO 6
#define POS_FREDO 8
// XXX (sizeof (play_menuitem) / sizeof (int))?
#define NUM_PLAYMENUITEMS 11

#define THUMBW 180
#define THUMBH 110

enum bmaction {
  BMA_NONE,
  BMA_SELECT,
  BMA_RENAME,
  BMA_DELETE,
  BMA_SETDEFAULT,
  BMA_OPTIMIZE,
  BMA_WATCH,
};

static const int bmi_zoomf = 2;
struct bookmarkitem : public menuitem {

  /* XX should base on size of level, number of bookmarks
     (base what? the size of the display? - tom) */


  /* with solution executed */
  level * lev;

  /* unsolved level, for communication with server */
  string levmd5;
  /* not owned */
  player * plr;

  /* the solution */
  namedsolution * ns;
  bool solved;

  drawable * below;

  /* XXX */
  virtual string helptext() {
    return "Press " BLUE "enter" POP " to load this bookmark.";
  }

  string bookmenu;
  string solmenu; 

  virtual void draw(int x, int y, int f) {
    drawing dr;
    dr.posx = x;
    dr.posy = y + 2;
    dr.width = THUMBW;
    dr.height = THUMBH;
    dr.margin = 0;
    dr.zoomfactor = bmi_zoomf;
    dr.scrollx = 0;
    dr.scrolly = 0;

    dr.lev = lev;
    dr.setscroll();
    dr.drawlev();
    
    if (f) {
      fon->draw(x + THUMBW + 4, y + 4, YELLOW + ns->name);
    } else {
      fon->draw(x + THUMBW + 4, y + 4, ns->name);
    }

    char da[256];
    const time_t t = ns->date;
    strftime(da, 255, "%H:%M:%S  %d %b %Y", localtime(&t));
    if (ns->author != "")
      fon->draw(x + THUMBW + 4, y + 4 + fon->height, "by " + ns->author);
    fon->draw(x + THUMBW + 4, y + 4 + (fon->height * 2), da);
    fon->draw(x + THUMBW + 4, y + 4 + (fon->height * 3), 
	      (string)(solved?PICS THUMBICON " " POP:PICS BOOKMARKPIC POP) +
	      itos(ns->sol->length) + " moves");

    if (f)
      fonsmall->draw(x + THUMBW + 4, 2 + y + 4 + (fon->height * 4),
		     BLUE + 
		     (solved?solmenu:bookmenu) + POP);

    // + (string)(solved?" " GREEN "(solved)":""));
  }

  virtual void size(int & w, int & h) {

    /* XXX also author, date.. */
    w = THUMBW + 8 + 
      util::maximum(fon->sizex(ns->name),
		    fonsmall->sizex(solmenu));

    /* at least 4 lines for text, plus menu,
       but then the minimum of the thumbnail height and the
       actual level's height at this zoom */
    h = util::maximum(8 + fonsmall->height + fon->height * 4,
		      util::minimum(THUMBH, 4 + lev->h * (TILEH >> bmi_zoomf)));

  }

  virtual inputresult key(SDL_Event e) {

    switch (e.key.keysym.sym) {
    case SDLK_RETURN:
      /* XXX if solution, maybe go straight to watching? */
      action.a = BMA_SELECT;
      return inputresult(MR_OK);

    case SDLK_d:
    case SDLK_DELETE:
      /* XXX warn especially if it is the last solution? */
      if (message::quick(container,
			 "Really delete '" YELLOW + 
			 ns->name + POP "'?",
			 "Delete",
			 "Cancel")) {

	action.a = BMA_DELETE;
	return inputresult(MR_OK);
      } else return inputresult(MR_UPDATED);

    case SDLK_INSERT: {
      /* only if it is solved */
      if (solved) {
	action.a = BMA_SETDEFAULT;
	return inputresult(MR_OK);
      } else {
	message::no(container, "Only a solution can be the default.");
	return inputresult(MR_UPDATED);
      }
    }
    case SDLK_u: {
      if (solved) {
	smanage::promptupload
	  (below, plr, levmd5,
	   ns->sol,
	   "Please only upload interesting solutions or speedruns.",
	   ns->name,
	   false);
      } else {
	message::no(container, "You can only upload full solutions.");
      }
      return inputresult(MR_UPDATED);
    }

    case SDLK_o: {
      /* only if it is solved */
      if (solved) {
	action.a = BMA_OPTIMIZE;
	return inputresult(MR_OK);
      } else {
	message::no(container, "You can only optimize solutions.");
	return inputresult(MR_UPDATED);
      }
    }

    case SDLK_r:
    case SDLK_F2: {
      action.s = prompt::ask(container, 
			     "New name: ", ns->name);
      if (action.s != "") {
	action.a = BMA_RENAME;
	return inputresult(MR_OK);
      } else {
	/* redraw */
	return inputresult(MR_UPDATED);
      }
    }

    case SDLK_w:
      action.a = BMA_WATCH;
      return inputresult(MR_OK);

    default:
      return menuitem::key(e);
    }
  }

  virtual inputresult click(int, int) {
    SDL_Event e;
    /* XXX is this enough to make it a legal key? */
    /* XXX should be a library call */
    e.type = SDL_KEYDOWN;
    e.key.keysym.sym = SDLK_RETURN;
    e.key.keysym.unicode = SDLK_RETURN;
    e.key.keysym.mod = (SDLMod) 0;
    return key(e);
  }

  struct act {
    bmaction a;
    string s;
  } action;

  /* copies lev, solution */
  bookmarkitem(level * l, namedsolution * n, player * p, string md, drawable * b) {
    bookmenu =
		   "[" YELLOW "r" POP WHITE "ename" POP "]" 
		   "[" YELLOW "d" POP WHITE "elete" POP "]" 
                   "[" YELLOW "w" POP WHITE "atch"  POP "]";

    solmenu =
                   bookmenu +
                   "[" YELLOW "u" POP WHITE "pload" POP "]"
                   "[" YELLOW "o" POP WHITE "ptimize" POP "]";

    lev = l->clone();
    ns = n->clone();
    int unused = 0;
    lev->play(n->sol, unused);
    solved = lev->iswon () && n->sol->length;
    action.a = BMA_NONE;
    plr = p;
    levmd5 = md;
    below = b;
  }
  
  void destroy() {
    lev->destroy();
    ns->destroy();
  }

};


void preal :: drawmenu() {
  int showw = (screen->w / TILEW) - 1;

  /* could be showw + 1 */
  for(int j = 0; j < showw; j++) {
    if (j == POS_MOVECOUNTER) {
      string count;
      if (solpos != sol->length) {
	count = itos(solpos) + GREY "/" POP BLUE +
	  itos(sol->length) + POP;
      } else {
	count = itos(sol->length);
      }
      fon->draw(2 + j * TILEW + 4, 2 + (TILEH>>1) - (fon->height>>1),
		count);
    } else if (play_menuitem[j] == MI_NODRAW) {
      /* nothing */
    } else if (play_menuitem[j] == TU_PLAYPAUSE) {
      /* if currently playing, draw this as a pause button, not a
	 play button */
      if (watching) {
	drawing::drawtileu(2 + j * TILEW, 2, TU_PLAYPAUSE_PLAY, 0);
      } else {
	drawing::drawtileu(2 + j * TILEW, 2, TU_PLAYPAUSE, 0);
      }
    } else if (j < NUM_PLAYMENUITEMS && play_menuitem[j]) {
      drawing::drawtileu(2 + j * TILEW, 2, play_menuitem[j], 0);
    }
  }

  /* disable menu items where appropriate (undo/redo) */
  if (solpos == 0) {
    /* nb. important that these two share disabled
       state, since the graphics overlap */
    drawing::drawtileu(POS_RESTART * TILEW, 2, TU_DISABLED, 0);
    drawing::drawtileu(POS_UNDO * TILEW, 2, TU_DISABLED, 0);
    drawing::drawtileu(POS_FUNDO * TILEW, 2, TU_DISABLED, 0);
  }

  if (solpos == sol->length) {
    drawing::drawtileu(POS_REDO * TILEW, 2, TU_DISABLED, 0);
    drawing::drawtileu(POS_FREDO * TILEW, 2, TU_DISABLED, 0);
    drawing::drawtileu(POS_PLAYPAUSE * TILEW, 2, TU_DISABLED, 0);
  }

#if 0 // can't do it because saved_sol not in scope...
  if (saved_sol->length == 0) {
    drawing::drawtileu(POS_RESTORESTATE * TILEW, 2, TU_DISABLED, 0);
  }
#endif

#if 0
  if (watching) {
    fon->draw(0, 8, GREEN "WATCHING" POP);
  }
#endif

  // if (filename == "") {
  //     drawing::drawtileu(POS_SAVE * TILEW, 0, TU_DISABLED, 0);
  //  }
  
}

void preal :: draw() {
  dr.setscroll();

  Uint32 color = 
    SDL_MapRGBA(screen->format, 0x22, 0x22, 0x44, 0xFF);

  /* clear back */
  sdlutil::clearsurface(screen, BGCOLOR);

  /* draw highlights and stuff */
  {
    SDL_Rect dst;
    dst.x = 2;
    dst.w = screen->w - 4;
    dst.y = 4 + TILEH;
    dst.h = fon->height + 4;
    SDL_FillRect(screen, &dst, color);
  }


  drawmenu();

  dr.drawlev(layer);

  if (showdests) dr.drawdests(0, showdestsshuffle);
  if (showbotnums) dr.drawbotnums();

  fon->drawto(screen, 4, TILEH + 6,
	      dr.lev->title + (string)" " GREY "by " POP BLUE + 
	      dr.lev->author + POP);

  switch(curstate()) {
  case STATE_OKAY: break;
  case STATE_DEAD:
    message::drawonlyv(screen->h - fon->height*8,
		       "You've died.",
		       "Try again",
		       "Quit", PICS SKULLICON);
    break;
  case STATE_WON:
    message::drawonlyv(screen->h - fon->height*8,
		       "You solved it!!",
		       "Continue", "", PICS THUMBICON);
    break;
  }

  /* XXX wrong, should use height,posy */
  // fon->drawto(surf, posx + 2, (surf->h) - (fon->height + 1), message);

  // dr.drawextra();
}

playstate preal :: curstate() {
  int unused;
  dir unusedd;
  if (solpos != 0 && dr.lev->isdead(unused, unused, unusedd)) 
    return STATE_DEAD;
  else if (solpos != 0 && dr.lev->iswon())
    return STATE_WON;
  else return STATE_OKAY;
}

void preal :: redraw () {
  draw();
  SDL_Flip(screen);
}

void preal:: screenresize () {
  dr.width = screen->w - dr.posx;
  dr.height = screen->h - dr.posy;
}

void preal::videoresize(SDL_ResizeEvent * eventp) {
  screen = sdlutil::makescreen(eventp->w, 
			       eventp->h);
  screenresize();
  redraw();
}

typedef ptrlist<aevent> elist;
typedef ptrlist<animation> alist;

bool preal::redo() {
  watching = false;
  if (curstate() == STATE_OKAY &&
      solpos < sol->length) {
    if (dr.lev->move(sol->dirs[solpos])) {
      solpos ++;
      return true;
    } else {
      message::no(this,
		  "Can't redo! (Illegal move!)");
      return false;
    }
  } else return false;
}

/* oh how I yearn for nested functions */
void preal::undo(level *& start, extent<level> & ec, int nm) {
  if (solpos > 0) {
    dr.lev->destroy();
    dr.lev = start->clone();
    ec.replace(dr.lev);

    /* move position backwards */
    solpos -= nm;
    if (solpos < 0) solpos = 0;

    int moves;
    dr.lev->play_subsol(sol, moves, 0, solpos);
    watching = false;
    redraw();
  }
}

void preal::restart(level *& start, extent<level> & ec) {
  dr.lev->destroy();
  solpos = 0;
  dr.lev = start->clone();
  ec.replace(dr.lev);
  watching = false;
  redraw();
}

/* set the player's solution set to the given array
   (of bookmarkitems) */

void preal::setsolseta(player * plr, string md5,
		       bookmarkitem ** books,
		       int n) {

  ptrlist<namedsolution> * solset = 0;
  
  for(int i = n - 1; i >= 0; i --) {
    solset = new ptrlist<namedsolution>(books[i]->ns->clone(), solset);
  }

  plr->setsolutionset(md5, solset);
  plr->writefile();
}

void preal::bookmarks(level * start, 
		      extent<level> & ec,
		      player * plr, string md5, 
		      solution *& sol,
		      extent<solution> & eso) {

  enum okaywhat_t { OKAYWHAT_HUH, OKAYWHAT_NEW=10, OKAYWHAT_DOWNLOAD, };

  bool show_menu_again;
  do {
    okaywhat_t okay_what = OKAYWHAT_HUH;
    show_menu_again = false;
    if (md5 == "") {
      message::bug(this, 
		   "Bookmarks aren't available because \n"
		   "I can't figure out what level this is!");
      redraw();
      return;
    }

    label nettitle;
    nettitle.text = PICS BARLEFT BAR BAR BARRIGHT POP " Server bookmarks "
      PICS BARLEFT BAR BAR BARRIGHT POP;

    label seltitle;
    seltitle.text = PICS BARLEFT BAR BAR BARRIGHT POP " Existing bookmarks "
      PICS BARLEFT BAR BAR BARRIGHT POP;

    label newtitle;
    newtitle.text = PICS BARLEFT BAR BAR BARRIGHT POP " Add a new bookmark "
      PICS BARLEFT BAR BAR BARRIGHT POP;

    textinput defname;
    defname.question = "New bookmark name:";
    /* XXX maybe generate in serial? */
    defname.input = "Bookmark";
    defname.explanation = "The bookmark will be saved with this name.";

    okay book_current;
    book_current.ptr = (int*)&okay_what;
    book_current.myval = OKAYWHAT_NEW;
    book_current.text = "Bookmark current state";
    book_current.explanation =
      "Bookmarks are saved in your player file,\n"
      "and allow you to come back to a place in\n"
      "solving the level where you left off.";

    cancel can;
    can.text = "Cancel";

    ptrlist<menuitem> * l = 0;

    ptrlist<menuitem>::push(l, &can);
    ptrlist<menuitem>::push(l, &book_current);
    ptrlist<menuitem>::push(l, &defname);
    ptrlist<menuitem>::push(l, &newtitle);

    /* initialize bmset with current bookmarks. */
    bool didsolve = false;
    bookmarkitem ** books = 0;
    int bmnum = 0;
    {
      ptrlist<namedsolution> * ss = plr->solutionset(md5);
      bmnum = ss->length();
      books = (bookmarkitem**) malloc(sizeof (bookmarkitem*) * bmnum);
      
      for(int i = 0; i < bmnum ; i ++) {
	if (!ss->head->bookmark) didsolve = true;
	bookmarkitem * tmp = new bookmarkitem(start, ss -> head, plr, md5, this);

	tmp->explanation = 
	  "Selecting this bookmark will load it,\n"
	  "losing your current progress.\n";

	ptrlist<menuitem>::push(l, tmp);
	books[i] = tmp;

	ss = ss -> next;
      }

    }
  
    /* only place 'existing' header if there are bookmarks */
    if (bmnum > 0) ptrlist<menuitem>::push(l, &seltitle);

    /* then if any bookmark is an actual solution, allow net access */
    okay netbutton;
    netbutton.ptr = (int*)&okay_what;
    netbutton.myval = OKAYWHAT_DOWNLOAD;
    netbutton.text = "Download solutions";
    netbutton.explanation =
      "Download all the solutions stored on the server,\n"
      "if you don't have them already.";

    if (didsolve) {
      ptrlist<menuitem>::push(l, &netbutton);
      ptrlist<menuitem>::push(l, &nettitle);
    }

    menu * mm = menu::create(this, "Bookmarks", l, false);
    extent<menu> em(mm);
    ptrlist<menuitem>::diminish(l);

    mm->yoffset = fon->height + 4;
    mm->alpha = 230;


    resultkind k = mm->menuize();

    switch(k) {
    case MR_OK: {
      /* MR_OK could come from hitting the OK button,
	 or hitting one of the bookmarks. so look
	 to see if it was a bookmark first. */

      for(int i = 0; i < bmnum; i ++) {
	bmaction a = books[i]->action.a;
	switch (a) {
	case BMA_NONE: break;
	
	case BMA_SETDEFAULT: {
	  
	  /* XXX does this work right?? 
	     should indicate the default bookmark here.
	     (or else maybe try to set the default
	     automatically, since it isn't very important) */

	  /* Swap it and the 0th element. */
	  bookmarkitem * tmp = books[bmnum - 1];
	  books[bmnum - 1] = books[i];
	  books[i] = tmp;

	  setsolseta(plr, md5, books, bmnum);
	  show_menu_again = true;
	  goto found_action;
	}
	case BMA_DELETE: {
	  
	  /* swap with last item */
	  bookmarkitem * tmp = books[bmnum - 1];
	  books[bmnum - 1] = books[i];
	  books[i] = tmp;
	  
	  /* remove last item */
	  bmnum --;

	  setsolseta(plr, md5, books, bmnum);
	  show_menu_again = true;
	  goto found_action;
	}
	case BMA_OPTIMIZE: {

	  solution * s = books[i]->ns->sol;
	  solution * so = optimize::opt(start, s);
	  if (so->length < s->length) {
	    s->destroy();
	    s = so;
	  } else {
	    so->destroy();
	  }

	  books[i]->ns->sol = s;
	  setsolseta(plr, md5, books, bmnum);

	  show_menu_again = true;
	  goto found_action;
	}
	case BMA_RENAME:
	
	  /* rename... */
	  books[i]->ns->name = books[i]->action.s;
	  
	  /* save... */
	  setsolseta(plr, md5, books, bmnum);
	  show_menu_again = true;

	  /* and restart... */
	  goto found_action;

	case BMA_WATCH: /* FALLTHROUGH */
	case BMA_SELECT: {
	  /* restore the bookmark */

	  dr.lev->destroy();
	  dr.lev = start->clone();
	  ec.replace(dr.lev);

	  sol->destroy();
	  sol = books[i]->ns->sol->clone ();
	  eso.replace(sol);

	  if (a == BMA_WATCH) {
	    watching = true;
	    nextframe = 0;
	    solpos = 0;
	  } else {
	    solpos = sol->length;
	    watching = false;
	    int moves;
	    dr.lev->play(sol, moves);
	  }

	  goto found_action;
	}
	}
      }

      /* didn't click on a bookmark. Could be one of the
	 other buttons... */

      switch(okay_what) {

      case OKAYWHAT_NEW: {
	/* bookmark new */
	{
	  /* need to trim this solution so that we are bookmarking
	     the current position without redos */
	  int oldlen = sol->length;
	  sol->length = solpos;
	  namedsolution ns(sol, 
			   (defname.input=="")?"Bookmark":defname.input,
			   /* no author */
			   "",
			   time(0),
			   true);
	  /* shouldn't make this default */
	  plr->addsolution(md5, &ns, false);
	  plr->writefile();
	  sol->length = oldlen;
	}
	/* message: "bookmark added" */
	break;
      }

      case OKAYWHAT_DOWNLOAD: {
	bookmark_download(plr, md5, start);
	show_menu_again = true;
	break;
      }
	
      default: {
 	message::bug(0, "huh?");
	break;
      }
      }

    }
    case MR_QUIT:
      /* XXX actually quit */
    case MR_CANCEL:
      /* cancel */
      break;
    }

  found_action:;

    /* now erase the bookmark menuitems */
    {
      for(int i = 0; i < bmnum; i ++) {
	books[i]->destroy();
      }
      free(books);
    }

  } while (show_menu_again);
  redraw();

}

/* XXX this should be documented in protocol.txt */
void preal::bookmark_download(player * plr, string lmd5, level * lev) {


  string s;
  client::quick_txdraw td;
  
  http * hh = client::connect(plr, td.tx, &td);

  if (!hh) { 
    message::no(&td, "Couldn't connect!");
    return;
  }

  extent<http> eh(hh);
  /* XXX register callback.. */

  httpresult hr = hh->get(ALLSOLS_URL + md5::ascii(lmd5), s);

  if (hr == HT_OK) {
    /* parse result. see protocol.txt */
    int nsols = stoi(util::getline(s));

    td.say("OK. Solutions on server: " GREEN + itos(nsols) + POP);

    /* get them! */
    for(int i = 0; i < nsols; i ++) {
      string line1 = util::getline(s);
      string author = util::getline(s);
      string moves = base64::decode(util::getline(s));

      /* this is the solution id, which we don't need */
      (void) stoi(util::chop(line1));
      int date = stoi(util::chop(line1));
      string name = util::losewhitel(line1);

      solution * s = solution::fromstring(moves);
      if (!s) {
	message::no(&td, "Bad solution on server!");
	return;
      }

      extent<solution> es(s);

      namedsolution ns;
      ns.sol = s;
      ns.name = name;
      ns.author = author;
      ns.date = date;
      /* nb. because we don't allow bookmarks on server yet */
      ns.bookmark = false;

      if (!plr->hassolution(lmd5, s))
	plr->addsolution(lmd5, &ns, true);

    }

    return;

  } else {
    message::no(&td, "Couldn't get solutions");
    return;
  }

}


void preal::checkpoint(solution *& saved_sol,
		       extent<solution> & ess) {
  saved_sol->destroy();
  saved_sol = sol->clone();
  /* shouldn't save redos */
  saved_sol->length = solpos;
  ess.replace(saved_sol);
  /* XXX should indicate that something has happened! */
  /* maybe show the checkpoint up at the top-right as a little
     image? */
  // dr.message= "Saved state.";
  watching = false;
}

void preal::restore(extent<level> & ec,
		    level * start,
		    solution * saved_sol,
		    extent<solution> & eso) {
  if (saved_sol->length > 0) {
    dr.lev->destroy();
    dr.lev = start->clone();
    ec.replace(dr.lev);
    
    sol->destroy();
    sol = saved_sol->clone ();
    eso.replace(sol);
    solpos = sol->length;

    /* this should stop playing
       as soon as we die or win... 
       (This can happen when we edit;
       the level can change while the
       solution persists)
    */
    int moves;
    dr.lev->play(sol, moves);
    sol->length = moves;
    watching = false;
    redraw();
  }
}

#define MINRATE 100
/* There are two ways to get an event. If there's a
   real event waiting in the queue, then we always
   return that.

   During watch mode, if there is no real event and
   at least MINRATE frames have passed since the
   last time, we can read a move off the redo future
   and play that. Since a redo won't reset the
   future, we can repeat this process until we reach
   the end of the solution.

   So that we can distinguish real keys from such
   fake keys, the argument 'fake' will be set true
   in the second case.
*/
bool preal::getevent(SDL_Event * e, bool & fake) {
  if (SDL_PollEvent(e)) {
    fake = false;
    return true;
  } 
  Uint32 now = SDL_GetTicks();
  if (watching && 
      solpos < sol->length &&
      now > nextframe) {
    nextframe = now + MINRATE;
    fake = true;
    /* XXX is this enough to make it a legal key? */
    e->type = SDL_KEYDOWN;
    e->key.keysym.mod = (SDLMod) 0;
    e->key.keysym.unicode = 0;
    switch(sol->dirs[solpos]) {
    case DIR_UP:    e->key.keysym.sym = SDLK_UP;    break;
    case DIR_DOWN:  e->key.keysym.sym = SDLK_DOWN;  break;
    case DIR_LEFT:  e->key.keysym.sym = SDLK_LEFT;  break;
    case DIR_RIGHT: e->key.keysym.sym = SDLK_RIGHT; break;
    }
    return true;
  } else return false;
}

playresult preal::doplay_save(player * plr, level * start, 
			      solution *& saved, string md5) {
  /* we never modify 'start' */
  dr.lev = start->clone();
  extent<level> ec(dr.lev);
  
  disamb * ctx = disamb::create(start);
  extent<disamb> edc(ctx);

  sol = solution::empty();
  solpos = 0;
  solution * saved_sol;

  /* if a solution was passed in, use it. */
  if (!saved) {
    saved_sol = solution::empty();
  } else {
    saved_sol = saved->clone ();
  }

  extent<solution> ess(saved_sol);
  extent<solution> eso(sol); 

  dr.scrollx = 0;
  dr.scrolly = 0;
  dr.posx = 0;
  /* room for menu (tiles), then title, and slack. 
     (since the drawing has built in slack (margin,
     we correct for that here too) */
  dr.posy = TILEH + fon->height + 4;
  screenresize();

  redraw();

  SDL_Event event;

  dr.message = "";

  /* XX avoid creating if animation is off? */
  dirt * dirty = dirt::create();
  extent<dirt> edi(dirty);

  bool pref_animate = 
    prefs::getbool(plr, PREF_ANIMATION_ENABLED);


  for(;;) {
    //  while ( SDL_WaitEvent(&event) >= 0 ) {
    SDL_Delay(1);
    
    bool fake = false;

    /* XXX shut off keyrepeat? */
    while ( getevent(&event, fake) ) {

      switch(event.type) {
      case SDL_QUIT: goto play_quit;
      case SDL_MOUSEBUTTONDOWN: {
	SDL_MouseButtonEvent * e = (SDL_MouseButtonEvent*)&event;

	if (e->button == SDL_BUTTON_LEFT) {

	  /* clicky? */
	  if (e->y <= TILEH + 4) {
	    int targ = (e->x - 2) / TILEW;
	    
	    if (targ < NUM_PLAYMENUITEMS) {
	      switch(play_menuitem[targ]) {
	      case TU_BOOKMARKS:
		bookmarks(start, ec, plr, md5, sol, eso);
		break;
	      case TU_RESTORESTATE:
		restore(ec, start, saved_sol, eso);
		break;
	      case TU_UNDO:
		undo(start, ec, 1);
		break;
	      case TU_REDO:
		redo();
		redraw();
		break;
	      case TU_PLAYPAUSE:
		watching = !watching;
		nextframe = 0;
		redraw();
		break;
	      case TU_FUNDO:
		undo(start, ec, 10);
		break;
	      case TU_FREDO:
		{ for(int i = 0; i < 10; i ++) redo(); }
		redraw();
		break;

	      case TU_RESTART:
		restart(start, ec);
		break;
	      case TU_SAVESTATE:
		checkpoint(saved_sol, ess);
		break;
	      }
	    }
	  }
	  
	  break;
	}
      }
      case SDL_KEYDOWN:

	switch(event.key.keysym.unicode) {
	  
	case SDLK_ESCAPE:
	  switch(curstate()) {
	  case STATE_WON:
	    /* XXX duplicated below. */
	    sol->length = solpos;
	    eso.release();
	    if (saved) saved->destroy();
	    saved = saved_sol->clone();
	    return playresult::solved(sol);

	  case STATE_DEAD: /* fallthrough */
	  case STATE_OKAY:
	    goto play_quit;
	  }
	  break;

	case SDLK_t:
	  restart(start, ec);
	  break;
	  
	case SDLK_RETURN:

	  watching = false;
	  switch (curstate()) {
	  case STATE_DEAD: /* fallthrough */
	  case STATE_OKAY: restart(start, ec); break;
	  case STATE_WON:
	    sol->length = solpos;
	    eso.release();
	    if (saved) saved->destroy();
	    saved = saved_sol->clone();
	    return playresult::solved(sol);
	  break;
	  }
	  break;

	  /* debugging "cheats" */
	case SDLK_LEFTBRACKET:
	case SDLK_RIGHTBRACKET:
	  dr.zoomfactor += (event.key.keysym.unicode == SDLK_LEFTBRACKET)? +1 : -1;
	  if (dr.zoomfactor < 0) dr.zoomfactor = 0;
	  if (dr.zoomfactor >= DRAW_NSIZES) dr.zoomfactor = DRAW_NSIZES - 1;

	  /* fix scrolls */
	  dr.makescrollreasonable();
	  redraw ();
	  break;

	case SDLK_y:
	  layer = !layer;
	  redraw();
	  break;

	case SDLK_b:
	  watching = false;
	  bookmarks(start, ec, plr, md5, sol, eso);
	  break;

	case SDLK_c:
	case SDLK_s:
	  checkpoint(saved_sol, ess);
	  break;
	case SDLK_i: {
	  /* import moves for solution
	     to different puzzle */
	  watching = false;
	  string answer = prompt::ask(this,
				      PICS QICON POP 
				      " What solution? (give md5 of level)");

	  if (answer != "") {
	    string md;
	    if (md5::unascii(answer, md)) {
	      solution * that;
	      if ( (that = plr->getsol(md)) ) {

		/* We now just append this solution but
		   don't "redo" it. The player can do
		   that himself with the VCR. */
		sol->length = solpos;
		sol->appends(that);

		redraw();

	      } else message::no(this, "Sorry, not solved!");
	    } else message::no(this, "Bad MD5");
	  }

	  redraw();

	  break;
	}
	case SDLK_r:
	  restore(ec, start, saved_sol, eso);
	  break;

	case SDLK_d:
	  showdests = !showdests;
	  redraw();
	  break;

	case SDLK_n:
	  showbotnums = !showbotnums;
	  redraw();
	  break;

	case SDLK_u: {
	  undo(start, ec, 1);
	  break;
	}

	case SDLK_p: {
	  watching = !watching;
	  nextframe = 0;
	  // printf("Watching: %d\n", (int)watching);
	  redraw ();
	  break;
	}

	case SDLK_o: {
	  redo();
	  redraw();
	  break;
	}

	default:
	  /* no unicode match; try sym */
      
	switch(event.key.keysym.sym) {

	case SDLK_d:
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    showdests = true;
	    showdestsshuffle = true;
	  }
	  redraw();
	  break;

	case SDLK_o:
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    for(int i = 0; i < 10; i ++) redo();
	    redraw();
	  }
	  break;

	case SDLK_u:
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    undo(start, ec, 10);
	    redraw();
	  }
	  break;

	/* ctrl-0 in play mode tries to recreate the solution,
	   starting from the current position, and using suffixes
	   of the bookmarks. */
	case SDLK_0: {
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    /* discard redo information */
	    watching = false;
	    printf("Trying to complete..\n");
	    sol->length = solpos;
	    solution * ss = 
	      optimize::trycomplete(start, sol,
				    plr->solutionset(md5));
	    if (ss) {
	      message::quick(this, "Completed from bookmarks: " GREEN
			     + itos(ss->length) + POP " moves",
			     "OK", "", PICS THUMBICON POP);
	      sol->destroy();
	      sol = ss;
	      eso.replace(sol);
	      /* put us at end of solution */
	      solpos = ss->length;

	      dr.lev->destroy();
	      dr.lev = start->clone();
	      ec.replace(dr.lev);
	      int moves;
	      dr.lev->play(sol, moves);
	      
	    } else {
	      message::no(this, "Couldn't complete from bookmarks.");
	    }
	    redraw();
	  }
	}

	case SDLK_END: {
	  while (redo()) ;
	  redraw();
	  break;
	}
	  
	case SDLK_HOME: {
	  restart(start, ec);
	  break;
	}

	case SDLK_DOWN:
	case SDLK_UP:
	case SDLK_RIGHT:
	case SDLK_LEFT: {

	  if (event.key.keysym.mod & KMOD_CTRL) {
	    switch(event.key.keysym.sym) {
	    case SDLK_DOWN: dr.scrolly ++; break;
	    case SDLK_UP: dr.scrolly --; break;
	    case SDLK_RIGHT: dr.scrollx ++; break;
	    case SDLK_LEFT: dr.scrollx --; break;
	    default: ; /* impossible */
	    }

	    redraw();
	    break;
	  }

	  /* can't move when dead or won... */
	  if (curstate () != STATE_OKAY) break;

	  /* if it's real, then cancel watching */
	  if (!fake) watching = false;

	  /* move */
	  dir d = DIR_UP;
	  switch(event.key.keysym.sym) {
	  case SDLK_DOWN: d = DIR_DOWN; break;
	  case SDLK_UP: d = DIR_UP; break;
	  case SDLK_RIGHT: d = DIR_RIGHT; break;
	  case SDLK_LEFT: d = DIR_LEFT; break;
	  default: ; /* impossible - lint */
	  }

	  bool moved;

	  if (pref_animate && !dr.zoomfactor) {
	    moved = animatemove(dr, ctx, dirty, d);
	  } else {
	    moved = dr.lev->move(d);
	  }

	  /* now end turn */
	  if (moved) {
	    /* add to solution, ... */

	    /* if we don't have any redo, or the move is different,
	       then we lose all redo and add this move */
	    if (solpos == sol->length || sol->dirs[solpos] != d) {
	      sol->length = solpos;
	      sol->append(d);
	    }
	    /* and either way, the solution position increases */
	    solpos ++;

	    dr.message = "";
	  }

	  /* no matter what, redraw so we change the direction
	     we're facing */
	  redraw();

	  break;
	}
	default:;
	}
	}
	break;
      case SDL_VIDEORESIZE: {
	SDL_ResizeEvent * eventp = (SDL_ResizeEvent*)&event;
	videoresize(eventp);
	/* sync size of dirty buffer */
	dirty->matchscreen();
	break;
      }
      case SDL_VIDEOEXPOSE:
	redraw();
	break;
      default: break;
      }
      SDL_Delay(1);
    }
    
  }
 play_quit:
  
  if (saved) saved->destroy();
  saved = saved_sol->clone();
  return playresult::quit();

}

void play::playrecord(string res, player * plr, bool allowrate) {
  /* only prompt to rate if this is in a
     web collection */
  bool iscollection;
  {
    string idx = 
      util::pathof(res) + (string)DIRSEP WEBINDEXNAME;
    dirindex * di = dirindex::fromfile(idx);
    iscollection = di?(di->webcollection ()):false;
    if (di) di->destroy();
  }

  string ss = readfile(res);

  string md5 = md5::hash(ss);

  /* load canceled */
  if (ss == "") return;

  level * lev = level::fromstring(ss);

  if (lev) { 

    play * pla = play::create();
    extent<play> ep(pla);

    playresult res = pla->doplay(plr, lev, md5);

    if (res.type == PR_ERROR || res.type == PR_EXIT) {
      lev->destroy();

      /* XXX should return something different */
      return;

    } else if (res.type == PR_QUIT) {
      /* back to level selection */
      lev->destroy();

      return;

    } else if (res.type == PR_SOLVED) {
      /* write solution, using file on disk 
	 (we have no reason to believe that our
	 tostring function will give us what is
	 on disk--despite what this code used
	 to indicate ;)) */

      /* is this our first solution (not including
	 bookmarks)? */
      bool firstsol = true;

      solution * sol = res.u.sol;
      solution * opt;

      /* remove any non-verfying solution first. we don't want to
	 erase non-verfying solutions eagerly, since that could cause
	 data lossage in the case that a new bugvision of the game
	 causes old good solutions to fail. But if we have something
	 to replace it with, and the player actively input that new
	 solution, then go for it... */

      {
	ptrlist<namedsolution> * sols = 
	  ptrlist<namedsolution>::copy(plr->solutionset(md5));
	ptrlist<namedsolution>::rev(sols);

	/* now filter just the ones that verify */
	/* XXX LEAK: I don't understand the interface to
	   (set)solutionset, so I don't free anything here. */
	ptrlist<namedsolution> * newsols = 0;
	while (sols) {
	  namedsolution * ns = ptrlist<namedsolution>::pop(sols);

	  level * check = level::fromstring(ss);
	  if (check) {
	    /* keep bookmarks too, since they basically never verify */
	    if (ns->bookmark || level::verify(check, ns->sol)) {
	      /* already solved it. */
	      if (!ns->bookmark) firstsol = false;
	      ptrlist<namedsolution>::push(newsols,
					   ns->clone());
	    }
	    check->destroy ();
	  }
	}

	plr->setsolutionset(md5, newsols);
      }

      /* free 'sol', and init 'opt' */
      if (prefs::getbool(plr, PREF_OPTIMIZE_SOLUTIONS)) {
	level * check = level::fromstring(ss);
	if (check) {
	  opt = optimize::opt(check, sol);
	  check->destroy ();
	} else opt = sol->clone ();
      } else {
	opt = sol->clone ();
      }
      sol->destroy ();
      
      
      {
	namedsolution ns(opt, "Untitled", plr->name, time(0), false);
	
	plr->addsolution(md5, &ns, true);
	plr->writefile();
      }

      opt->destroy();


      if (allowrate &&
	  plr->webid &&
	  firstsol &&
	  iscollection &&
	  !plr->getrating(md5) &&
	  prefs::getbool(plr, PREF_ASKRATE)) {

	ratescreen * rs = ratescreen::create(plr, lev, md5);
	if (rs) {
	  extent<ratescreen> re(rs);
	  rs->setmessage(YELLOW
			 "Please rate this level." POP
			 GREY " (You can turn off this "
			 "automatic prompt from the preferences menu.)" POP);
		  
	  rs->rate();
	} else {
	  message::bug(0, "Couldn't create rate object!");
	}

      }
      lev->destroy();

      /* load again ... */
      return;
    } else {
      printf ("????\n");
      return ;
    }

  } else return;
}

bool play::animatemove(drawing & dr, disamb *& ctx, dirt *& dirty, dir d) {
  /* events waiting to be turned into animations */
  elist * events = 0;
  /* current phase of animation */
  alist * anims = 0;
  /* current sprites (drawn on top of everything) */
  alist * sprites = 0;


  /* clear sprites from screen.
     sprites are always drawn on top of
     everything, so eagerly clearing
     them here makes sense.

     after we call move, clearsprites
     is worthless to us, since the
     underlying level will have changed. */
 
  animation::clearsprites(dr);
  
  bool success = dr.lev->move_animate(d, ctx, events);

  /* loop playing animations. */
  while(sprites || anims || events) {
    unsigned int now = SDL_GetTicks();

    /* are we animating? if so, trigger 
       the next animation action. */
    if (anims || sprites) {

      /* spin-wait until something is ready to think.
	 this is the only reason we draw */
      bool ready = false;
      do {
	// printf("  %d Checked!\n", cycle);
	SDL_PumpEvents();
	if (SDL_PeepEvents(dummy, 255, SDL_PEEKEVENT,
			   SDL_EVENTMASK(SDL_KEYDOWN) |
			   SDL_EVENTMASK(SDL_VIDEORESIZE) |
			   SDL_EVENTMASK(SDL_MOUSEBUTTONDOWN) |
			   SDL_EVENTMASK(SDL_QUIT))) {
	  // printf("  %d did short circuit\n", cycle);
	  /* key waiting. abort! */
	  /* empty the lists and be done */
	  while (events) delete elist::pop(events);
	  while (anims) delete alist::pop(anims);
	  while (sprites) delete alist::pop(sprites);

	  return success;
	}

	bool only_finales = true;

	{
	  for(alist * atmp = anims; atmp && !ready; 
	      atmp = atmp -> next) {
	    if (!atmp->head->finale) only_finales = false;
	    if (atmp->head->nexttick < now) {
	      ready = true;
	    }
	  }
	}

	{
	  for(alist * atmp = sprites; atmp && !ready; 
	      atmp = atmp -> next) {
	    if (!atmp->head->finale) only_finales = false;
	    if (atmp->head->nexttick < now) {
	      ready = true;
	    }
	  }
	}

	/* if there are only finales, then we are ready.
	   (they will do their death wail) */
	if (only_finales) {
	  ready = true;
	}

	/* if nothing is ready, then don't chew CPU */
	/* XXX PERF ever delay when animations are going? */
	if (!ready) SDL_Delay(0);
	now = SDL_GetTicks ();
      } while (!ready);

      /* 

      the new regime is this:

      in each loop,
      - erase all animations.
      - if any animation is ready to
      think, make it think.
      (the animation may 'become'
      a different animation at
      this point; call its init
      method)
      - draw all active animations.
      - draw all active sprites on
      top of that.

      */

      animation::erase_anims(anims, dirty);
      animation::erase_anims(sprites, dirty);

      /* reflect dirty rectangles action */
      dirty->clean();

      bool remirror = false;

      animation::think_anims(&anims, now, remirror);
      animation::think_anims(&sprites, now, remirror, !anims);

      /* might need to save new background */
      if (remirror) dirty->mirror();

      /* now draw everything, but only if
	 there is something left. */

      /* printf("\n == draw cycle == \n"); */
      if (anims || sprites) {

	/* Sort animations by y-order every time! */
	alist::sort(animation::yorder_compare, anims);
	alist::sort(animation::yorder_compare, sprites);

	animation::draw_anims(anims);
	animation::draw_anims(sprites);
		
	SDL_Flip(screen);

	POSTDRAW ;
	/* if (pref_debuganim) SDL_Delay(80); */
      }

    } else {
      /* no? then we should have some events queued
	 up to deal with. */

      if (events) {
	unsigned int s = events->head->serial;
	/* push all events with the same serial */
	// printf("** doing serial %d\n", s);
	while (events && events->head->serial == s) {
	  aevent * ee = elist::pop(events);
	  extentd<aevent> eh(ee);
	  animation::start(dr, anims, sprites, ee);
	}

	if (anims || sprites) {

	  bool domirror = false;
	  domirror = animation::init_anims(anims, now) || domirror;
	  domirror = animation::init_anims(sprites, now) || domirror;
		  
	  /* PERF check return code to be more efficient */
	  dirty->mirror();
	}
      }
    }
  }

  return success;

}
