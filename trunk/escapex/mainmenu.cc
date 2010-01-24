
#include "mainmenu.h"
#include "draw.h"
#include "extent.h"
#include "version.h"
#include "util.h"
#include "prefs.h"
#include "chars.h"
#include "client.h"
#include "load.h"
#include "message.h"
#include "play.h"
#include "handhold.h"
#include "md5.h"
#include "backgrounds.h"

/* testing */
#include "animation.h"

#define TUTORIAL_DIR "official" DIRSEP "tutorial"
#define TITLE_FILE DATADIR "title.png"
#define TITLE_OFFSET 16

#define SHOWY (400 - 32)

#define TEXTOFFSET (titlegraphic->h + 8 + 32)
#define TEXTX ((screen->w - titlegraphic->w) >> 1)
#define RECOMMENDED_TEXT YELLOW "Recommended " POP PICS ARROWR POP " "

enum mmetype {
  MM_TUTORIAL,
  MM_LOAD,
  MM_EDIT,
  MM_UPGRADE,
  MM_UPDATE,
  MM_PREFS,
  MM_QUIT,
  MM_LOAD_NEW,
  MM_N_ITEMS,
};

struct mmentry {
  struct mmreal * parent;
  mmetype t;
  static int height() { return TILEH - 8; }
  mmetype convert() { return t; }
  mmetype none() { return MM_QUIT; }
  void swap(mmentry *, mmentry *) { /* unnecessary, no sorting */ }
  /* no matches, because we catch these keys ourselves */
  bool matches(char) { return false; }
  void draw(int x, int y, bool sel);
};

typedef selector<mmentry, mmetype> msel;

#if 0
/* FIXME testing only! */
static char threadmsg[256] = "";
static int threadtest(void * unused) {
  threadmsg[255] = 0;
  sprintf(threadmsg, "start..");
  string f = readfile("animation.png");
  f = f + f + f + f + f + f;
  f = f + f + f + f;
  string s = md5::ascii(md5::hash(f + f + f + f + f));
  sprintf(threadmsg, s.c_str());
  return 0;
}
#endif

struct mmreal : public mainmenu, public drawable {

  virtual mainmenu::result show();
  virtual void destroy();

  static mmreal * create(player * plr);

  /* for drawable */
  virtual void draw();
  virtual void screenresize();

  virtual ~mmreal() {}

 private:
  friend struct mmentry;

  void redraw () {
    sel->draw ();
    SDL_Flip(screen);
  }

  msel * sel;

  player * pp;
  SDL_Surface * titlegraphic;
  SDL_Surface * background;

  mainshow * mshow;

  void makebackground ();
  void compute_tutorial ();
  bool tutorial_left;
  string tutorial_text;
  string tutorial_nextlev;

  void playtutorial() {

    if (tutorial_left &&
	tutorial_nextlev != "") {
	  
      play::playrecord(tutorial_nextlev, pp, false);
      compute_tutorial ();
	    
    } else {
      message::quick(this, "Tutorial completed or unavailable!",
		     "Sorry", "", PICS XICON POP);
    }

  }

  int startx() {
    /* XXX ?!? */
    return TEXTX + fon->sizex(RECOMMENDED_TEXT);
  }

};

void mmentry::draw(int x, int y, bool sel) {

  int sxi = parent->startx();
  int sx = sxi + TILEW + 16;
  /* recommended text */
  int sxr = sxi - (fon->sizex(RECOMMENDED_TEXT) + 16);

  y -= 4;
  int ctry = y + ((height() >> 1) - (fon->height >> 1)) + 4;

  switch(t) {
  case MM_TUTORIAL:
    /* figure out what the next unsolved tutorial level is */
    drawing::drawtileu(sxi, y, TU_T, 0, screen);
    if (parent->tutorial_left)
      fon->draw(sx, ctry, parent->tutorial_text);
    else
      fon->draw(sx, ctry, GREY + parent->tutorial_text);
    break;
  case MM_LOAD:
    drawing::drawtileu(sxi, y, TU_1, 0, screen);
    fon->draw(sx, ctry, YELLOW "Load a level.");
    break;
  case MM_LOAD_NEW:
    drawing::drawtileu(sxi, y, TU_LOAD, 0, screen);
    fon->draw(sx, ctry, YELLOW "New level browser!");
    break;

  case MM_EDIT:
    drawing::drawtileu(sxi, y, TU_2, 0, screen);
    fon->draw(sx, ctry, "Edit a level.");
    break;

# ifndef MULTIUSER
  case MM_UPGRADE:
    drawing::drawtileu(sxi, y, TU_3, 0, screen);
    if (handhold::recommend_upgrade())
      fon->draw(sxr, ctry, RECOMMENDED_TEXT);

    fon->draw(sx, ctry, "Upgrade Escape from internet.");
    break;
# endif

  case MM_UPDATE:
    drawing::drawtileu(sxi, y, TU_4, 0, screen);
    /* don't show more than one recommendation */
    if (handhold::recommend_update() && !handhold::recommend_upgrade())
      fon->draw(sxr, ctry, RECOMMENDED_TEXT);

    fon->draw(sx, ctry, "Get new levels from internet.");
    break;

  case MM_PREFS:
    drawing::drawtileu(sxi, y, TU_P, 0, screen);
    fon->draw(sx, ctry, "Change preferences.");
    break;
  case MM_QUIT:
    drawing::drawtileu(sxi, y, TU_X, 0, screen);
    fon->draw(sx, ctry, "Quit.");
    break;


  default:
    fon->draw(sx, y, RED "???");
  }
}


void mmreal::compute_tutorial () {
  // XXX use leveldb for this.

  loadlevel * ll = loadlevel::create(pp, TUTORIAL_DIR, false, false);
  if (!ll) {
    tutorial_left = false;
    tutorial_nextlev = "error.esx";
    tutorial_text = "(" RED "Tutorial missing!" POP ")";
    return ;
  }
  extent<loadlevel> el(ll);

  /* search through loader for first unsolved level */
  tutorial_left = ll->first_unsolved(tutorial_nextlev, tutorial_text);
  if (!tutorial_left) tutorial_text = "Tutorial complete.";
}

void mmreal::draw() {

  SDL_BlitSurface(background, 0, screen, 0);

  /* XXX */
  // fon->draw(0, 0, threadmsg);

  /* draw status info at the bottom */
  int y = screen->h - (int)(fon->height * 3.2f);

  if (pp->webid) {
    fon->draw(6, y += fon->height,
	      (string)BLUE + pp->name + (string)GREY " is Player #" POP +
	      itos(pp->webid) + POP);
  } else {
    if (network) {
      fon->draw(6, y += fon->height, WHITE
		"Press [" YELLOW "R" POP "] to register your player online!" 
		POP);
    } else {
      fon->draw(6, y += fon->height, GREY
		"(connect to the internet to register your player online)" 
		POP);
    }
  }

  y += fon->height;
  fon->draw(6, y, 
	    PICS BARLEFT BAR BAR BARRIGHT POP 
	    BLUE "ESCAPE " POP GREY "Version " VERSION POP 
	    PICS BARLEFT BAR BAR BARRIGHT POP);

  {
    string web = GREY "http://" BLUE DEFAULT_SERVER POP "/";
    fon->draw(screen->w - fon->sizex(web) - 6, y, web);
  }


  mshow->draw((screen->w - mshow->width()) >> 1, SHOWY, screen);
}


#define FRAME_TICKS 500
mainmenu::result mmreal::show() {
  compute_tutorial ();

  makebackground ();
  redraw();

  SDL_Event e;

  Uint32 nextframe = SDL_GetTicks() + FRAME_TICKS;
  for( ;; ) {
    SDL_Delay(1);

    /* turn on animation? */
    Uint32 now = SDL_GetTicks();

    if (now > nextframe) {
      mshow->step ();
      nextframe = now + FRAME_TICKS;
      redraw ();
    }

    while (SDL_PollEvent(&e)) {
      int key;

      if (handle_video_event(this, e)) continue;

      switch(e.type) {
      case SDL_QUIT:
	return QUIT;

      case SDL_KEYDOWN:
	key = e.key.keysym.sym;
	switch(key) {

#if 0
	case SDLK_z:
	  SDL_CreateThread(threadtest, (void*)0);
	  redraw();
	  continue;
#endif

	case SDLK_ESCAPE:
	case SDLK_x:
	  return QUIT;

	case SDLK_l:
	case SDLK_1:
	  return LOAD;

	case SDLK_b:
	  return LOAD_NEW;

	case SDLK_e:
	case SDLK_2:
	  return EDIT;

#       ifndef MULTIUSER
	case SDLK_u:
	case SDLK_3:
	  if (network) return UPGRADE;
	  else continue;
#       endif

	case SDLK_g:
	case SDLK_4:
	  if (network) return UPDATE;
	  else continue;

	case SDLK_t: {
	  /* XXX shouldn't this be a return TUTORIAL or whatever? */
	  playtutorial();
	  redraw();
	  continue;
	}

	case SDLK_p: {
	  prefs::show(pp);
	  redraw();
	  continue;
	}

	case SDLK_r: {
	  if (network && !pp->webid) return REGISTER;
	  else continue;
	}

	default: break;

	}
      default: break;
      }

      /* if we got here, then we don't know how to
	 preempt the event, so use the selector. */
      msel::peres pr = sel->doevent(e);
      switch(pr.type) {
      case msel::PE_SELECTED:
	switch(sel->items[sel->selected].t) {
	case MM_TUTORIAL:
	  playtutorial();
	  redraw();
	  continue;
	case MM_LOAD: return LOAD;
	case MM_LOAD_NEW: return LOAD_NEW;
	case MM_EDIT: return EDIT;
	case MM_QUIT: return QUIT;
	case MM_UPGRADE:
	    if (network) return UPGRADE;
	    else continue;
	case MM_UPDATE:
	    if (network) return UPDATE;
	    else continue;
	case MM_PREFS:
	    prefs::show(pp);
	    redraw();
	    continue;
	default: break;
	}
	/* ??? */
	break;
	/* FALLTHROUGH */
      case msel::PE_EXIT:
      case msel::PE_CANCEL:
	return QUIT;
      default:
      case msel::PE_NONE:;
      }
    }
  }

  return QUIT;
}

void mmreal::screenresize() {
  makebackground();
}

/* the background is pretty complex, so we precompute it */
void mmreal::makebackground() {
  int w = screen->w;
  int h = screen->h;

  backgrounds::gradientblocks(background,
			      T_GREY,
			      T_BLUE,
			      backgrounds::blueish);
  if (!background) return;

  /* draw alpharect for bottom */
  int botoff = fon->height * 2 + 4;
  SDL_Surface * bot = sdlutil::makealpharect(w, botoff,
					     0, 0, 0, 120);
  if (bot) {
    SDL_Rect dest;
    dest.x = 0;
    dest.y = h - (botoff + 1);
    SDL_BlitSurface(bot, 0, background, &dest);
    SDL_FreeSurface(bot);
  }

  /* bg for titlegraphic */
  bot = sdlutil::makealpharect(w, titlegraphic->h + 16, 0, 0, 0, 120);
  if (bot) {
    SDL_Rect dest;
    dest.x = 0;
    dest.y = TITLE_OFFSET - 8;
    SDL_BlitSurface(bot, 0, background, &dest);
    SDL_FreeSurface(bot);
  }

  /* title graphic */
  {
    int sx = TEXTX;
    SDL_Rect dest;
    dest.x = sx;
    dest.y = 16;
    
    SDL_BlitSurface(titlegraphic, 0, background, &dest);
  }

  /* and the background for the text */
  bot = sdlutil::makealpharect(w, 
			       16 +
			       sel->number *
			       mmentry::height(),
			       0, 0, 0, 120);

  if (bot) {
    SDL_Rect dest;
    dest.x = 0;
    dest.y = TEXTOFFSET - 8;
    SDL_BlitSurface(bot, 0, background, &dest);
    SDL_FreeSurface(bot);
  }

}

mainmenu * mainmenu::create(player * plr) {
  return mmreal::create(plr);
}

mmreal * mmreal::create(player * plr) {

  mmreal * mm = new mmreal();
  if (!mm) return 0;
  mm->titlegraphic = 0;
  mm->background = 0;

  extent<mmreal> em(mm);

  mm->titlegraphic = sdlutil::imgload(TITLE_FILE);

  if (!mm->titlegraphic) return 0;

  mm->pp = plr;

  mm->tutorial_left = false;

  mm->mshow = new mainshow(18, 10, 1);

  /* set up selector... */
  mm->sel = msel::create(MM_N_ITEMS);
  mm->sel->below = mm;  
  /* XXX should be a better way to do this. 
     (should really get it from titlegraphic, for one) */
  mm->sel->title = "\n\n\n\n\n\n\n\n\n\n";
  for(int j = 0; j < MM_N_ITEMS; j++) {
    mm->sel->items[j].parent = mm;
  }
  
  int i = 0;
  
  mm->sel->selected = 1;
  if (prefs::getbool(plr, PREF_SHOWTUT)) {
    mm->sel->items[i++].t = MM_TUTORIAL;

    /* select tutorial if there's something left. */
    mm->compute_tutorial();
    if (mm->tutorial_left) 
      mm->sel->selected = 0;
  }

  mm->sel->items[i++].t = MM_LOAD;
  mm->sel->items[i++].t = MM_LOAD_NEW;
  mm->sel->items[i++].t = MM_EDIT;
  if (network) {
#   ifndef MULTIUSER
    mm->sel->items[i++].t = MM_UPGRADE;
#   endif
    mm->sel->items[i++].t = MM_UPDATE;
  }

  mm->sel->items[i++].t = MM_PREFS;
  mm->sel->items[i++].t = MM_QUIT;


  /* FIXME the rest ... */

  /* maybe fewer, if some were removed */
  mm->sel->number = i;

  em.release();
  return mm;
}

void mmreal::destroy () {
  if (titlegraphic) SDL_FreeSurface(titlegraphic);
  if (background) SDL_FreeSurface(background);
  if (mshow) delete mshow;
  delete this;
}
