
// XXX trim.
// Things like client operations (upload/comment) need to be in 
// separate files.
#include "escapex.h"
#include "level.h"
#include "sdlutil.h"
#include "browse.h"
#include "md5.h"
#include "backgrounds.h"

#include <string.h>
#include <sys/stat.h>
#include <time.h>

#include "dirent.h"

#include "extent.h"
#include "dircache.h"
#include "util.h"
#include "chars.h"

#include "message.h"
#include "upload.h"
#include "prompt.h"

#include "leveldb.h"
#include "commenting.h"

#include "optimize.h"
#include "client.h"
#include "animation.h"

#include "menu.h"

#include "progress.h"

#ifdef LINUX
/* just used for debugging */
#  include <sys/time.h>
#endif

/* how frequently to make a move in solution playback */
#define LOADFRAME_TICKS 100
#define STEPS_BEFORE_SOL 5

#if 0
struct llentry {
  /* Global level/collection information. */
  one_result lev;

  /* Denormalized other info? */
  static int height() { return fon->height; }
  string display(bool selected);
  void draw(int x, int y, bool sel);
  string convert() { return fname; }
};
#endif

struct browse_ : public browse {
  browse_() : background(0) {}

  virtual void draw() {
    SDL_BlitSurface(background, 0, screen, 0);
  }

  virtual void screenresize() {
    makebackground();
  }
  
  virtual void destroy() {
    // if (showlev) showlev->destroy();
    delete this;
  }

  virtual string selectlevel();

  void makebackground();
  SDL_Surface * background;

  void redraw() {
    draw();
    SDL_Flip(screen);
  }

  /* From constructor argument. */
  bool allow_corrupted;

  /* save query we performed. */
  static lquery lastquery;
  /* and last MD5 we selected */
  static string lastmd5;
};

void browse_::makebackground() {
  int w = screen->w;
  int h = screen->h;

  backgrounds::gradientblocks(background,
			      T_GREY,
			      T_RED,
			      backgrounds::purpleish);
  if (!background) return;

  const Uint32 curveborder_color =
    SDL_MapRGBA(background->format, 163, 102, 102, 255);

  /* Border around the whole thing. */

  /* Curves are square. */
  const int curve_size = 12;
  const int curveborder_width = 3;
  const int border_x1 = 17, border_y1 = 13;
  const int border_x2 = w - 17, border_y2 = h - 13;

  /* Curves */
  sdlutil::blitall(animation::curveborder_tan_tl, background,
		   border_x1, border_y1);
  sdlutil::blitall(animation::curveborder_tan_tr, background,
		   border_x2 - curve_size, border_y1);
  sdlutil::blitall(animation::curveborder_tan_br, background,
		   border_x2 - curve_size, border_y2 - curve_size);
  sdlutil::blitall(animation::curveborder_tan_bl, background,
		   border_x1, border_y2 - curve_size);

  const int inborder_height = border_y2 - border_y1 - curve_size * 2;
  const int inborder_width = border_x2 - border_x1 - curve_size * 2;

  /* Thick border connecting curves */
  /* left */
  sdlutil::fillrect(background, curveborder_color,
		    border_x1, border_y1 + curve_size,
		    curveborder_width, 
		    inborder_height);

  /* top */
  sdlutil::fillrect(background, curveborder_color,
		    border_x1 + curve_size, 
		    border_y1,
		    inborder_width,
		    curveborder_width);

  /* right */
  sdlutil::fillrect(background, curveborder_color,
		    border_x2 - curveborder_width,
		    border_y1 + curve_size,
		    curveborder_width,
		    inborder_height);

  /* bottom */
  sdlutil::fillrect(background, curveborder_color,
		    border_x1 + curve_size,
		    border_y2 - curveborder_width,
		    inborder_width,
		    curveborder_width);
  
  /* Partially-translucent insides. */
  {
    SDL_Surface * vert = sdlutil::makealpharect(curve_size - curveborder_width,
						inborder_height,
						0, 0, 0, 0.8 * 255);
    SDL_Surface * horiz = sdlutil::makealpharect(inborder_width,
						 curve_size - curveborder_width,
						 0, 0, 0, 0.8 * 255);
    SDL_Surface * center = sdlutil::makealpharect(inborder_width,
						  inborder_height,
						  0, 0, 0, 0.8 * 255);
   
    /* left and right */
    sdlutil::blitall(vert, background, 
		     border_x1 + curveborder_width,
		     border_y1 + curve_size);

    sdlutil::blitall(vert, background, 
		     border_x2 - curve_size,
		     border_y1 + curve_size);
    
    /* top and bottom */
    sdlutil::blitall(horiz, background,
		     border_x1 + curve_size,
		     border_y1 + curveborder_width);

    sdlutil::blitall(horiz, background,
		     border_x1 + curve_size,
		     border_y2 - curve_size);

    /* center */
    sdlutil::blitall(center, background,
		     border_x1 + curve_size,
		     border_y1 + curve_size);

    SDL_FreeSurface(vert);
    SDL_FreeSurface(horiz);
    SDL_FreeSurface(center);
  }

  const int title_x = 39, title_y = 31;
  sdlutil::blitall(animation::choose_a_level, background, title_x, title_y);

  /* bottom panel */
  const int bottom_height = 169;

  /* separator bars */
  const Uint32 separator_color = 
    SDL_MapRGBA(background->format, 92, 59, 59, 255);
  const int separator_x = border_x1 + curveborder_width + 1;
  const int separator_width = border_x2 - border_x1 - curveborder_width * 2 - 2;
  const int separator_height = 2;
  const int topsep_y = 112;
  const int botsep_y = border_y2 - bottom_height - separator_height;

  sdlutil::fillrect(background, separator_color,
		    separator_x, topsep_y, separator_width, separator_height);

  sdlutil::fillrect(background, separator_color,
		    separator_x, botsep_y, separator_width, separator_height);
}

string browse_::selectlevel() {
  SDL_Event event;

  Uint32 nextframe = SDL_GetTicks() + LOADFRAME_TICKS;
  redraw();

  for(;;) {
    SDL_Delay(1);

    Uint32 now = SDL_GetTicks();
  
    while (SDL_PollEvent(&event)) {

      if (handle_video_event(this, event)) continue;

      if ( event.type == SDL_KEYDOWN ) {
	int key = event.key.keysym.sym;
	/* breaking from here will allow the key to be
	   treated as a search */

	switch(key) {
	  // Handle special keys...
	default:;
	} 

      }

      // XXX bogus. use selector.
      switch (event.type) {
      case SDL_QUIT:
	return "";
      default:;
      }
    }

  } /* unreachable */

}


browse * browse::create(bool allow_corrupted) {
  browse_ * b = new browse_;
  b->allow_corrupted = allow_corrupted;
  b->makebackground();
  return b;
}


#if 0

loadlevelreal::sortstyle loadlevelreal :: sortby = loadlevelreal::SORT_DATE;
string loadlevelreal :: lastdir;
string loadlevelreal :: lastfile;

loadlevel :: ~loadlevel () {}

void loadlevelreal::select_lastfile() {
  for(int i = 0; i < sel->number; i ++) {
    if (sel->items[i].fname == lastfile) sel->selected = i;
  }
}

void loadlevelreal::fix_show(bool force) {
  /* if we notice that we are out of sync with the selected
     level, switch to it. */
  
  /*
  printf("fix_show. sel->selected %d, showidx %d, showlev %p, sol %p\n",
	 sel->selected, showidx, showlev, showsol);
  */

  if (force || (sel->selected != showidx)) {

    showidx = sel->selected;
    if (showlev) showlev->destroy();
    showlev = 0;
    showsol = 0;

    /* directory might be totally empty?? */
    if (sel->number) {

      /*
      printf("about to read from showidx %d. there are %d", showidx,
	     sel->number);
      */
      if (!sel->items[showidx].isdir) {
	// printf("well the level is %p\n", sel->items[showidx].lev);
	showlev = sel->items[showidx].lev->clone();
	if ( (showsol = plr->getsol(sel->items[showidx].md5)) ) {
	  solstep = 0;
	  showstart = STEPS_BEFORE_SOL;
	}
      }
    } else {
      // printf("empty dir!\n");
    }
    
  }

  // printf("exit fix_show\n");

}

void loadlevelreal::step() {

  fix_show ();

  /* now, if we have a lev, maybe make a move */
  if (showlev && showsol) {
    if (!showstart) {
      /* step */
      if (solstep < showsol->length) {
	dir d = showsol->dirs[solstep];
	showlev->move(d);
	solstep ++;
      }

    } else showstart --;
  }
}


/* PERF could precompute most of this */
void llentry::draw (int x, int y, bool selected) {
  fon->draw(x, y, display(selected));
}

string llentry::display(bool selected) {
  string color = WHITE;
  if (selected) color = YELLOW;

  unsigned int ns = 32;
  unsigned int ss = 6;
  unsigned int as = 24;

  if (isdir) {

    if (fname == "..") {
      return (string)"   " + color + (string)"[..]" POP;
    } else {
      string pre = "   ";
      if (total > 0 && total == solved) pre = YELLOW LCHECKMARK " " POP;

      string so = "";
      if (total > 0) {
	so = itos(solved) + (string)"/" + itos(total);
      } else {
	if (!selected) color = GREY;
	so = "(no levels)";
      }

      string showname = "";
      if (name != "") showname = name;
      else showname = fname;

      return pre + 
	color + (string)"[" + showname + (string)" " + so + "]" POP;
    }
  } else {
    string pre = "   ";
    if (owned) pre = PICS KEYPIC " " POP;
    else if (solved) pre = YELLOW LCHECKMARK " " POP;

    string myr = "  " "  " "  ";

    if (myrating) {
      myr = 
	(string)RED   BARSTART + (char)(BAR_0[0] + (int)(myrating->difficulty)) +
	(string)GREEN BARSTART + (char)(BAR_0[0] + (int)(myrating->style)) +
	(string)BLUE  BARSTART + (char)(BAR_0[0] + (int)(myrating->rigidity));
    }

    /* shows alpha-dimmed if there are fewer than 3(?) votes */
    string ratings = "  " "  " "  ";
    if (votes.nvotes > 0) {
      ratings = 
	(string)((votes.nvotes <= 2)? ((votes.nvotes <= 1) ? ALPHA25 : ALPHA50) : "") +
	(string)RED   BARSTART + (char)(BAR_0[0] + (int)(votes.difficulty / votes.nvotes)) +
	(string)GREEN BARSTART + (char)(BAR_0[0] + (int)(votes.style / votes.nvotes)) +
	(string)BLUE  BARSTART + (char)(BAR_0[0] + (int)(votes.rigidity / votes.nvotes));    }

    string line =
      pre + color + font::pad(name, ns) + (string)" " POP + 
      (string)(corrupted?RED:GREEN) + 
      font::pad(itos(sizex) + (string)GREY "x" POP +
		itos(sizey), ss) + POP +
      (string)" " BLUE + font::pad(author, as) + POP + myr + 
      (string)" " + ratings;

    return line;
  }
}

bool llentry::matches(char k) {
  if (name.length() > 0) return util::library_matches(k, name);
  else return (fname.length () > 0 && (fname[0] | 32) == k);
}

bool loadlevelreal::first_unsolved(string & file, string & title) {
  /* should use this natural sort, since this is used for the
     tutorials */
  sel->sort(getsort(SORT_ALPHA));

  for(int i = 0; i < sel->number; i ++) {
    if ((!sel->items[i].isdir) &&
	(!sel->items[i].solved)) {
      file = sel->items[i].actualfile(path);
      title = sel->items[i].name;
      return true;
    }
  }
  /* all solved */
  return false;
}

/* measuring load times -- debugging only. */
#if 0  // ifdef LINUX
#  define DBTIME_INIT long seclast, useclast; { struct timeval tv; gettimeofday(&tv, 0); seclast = tv.tv_sec; useclast = tv.tv_usec; }
#  define DBTIME(s) do { struct timeval tv; gettimeofday(&tv, 0); int nsec = tv.tv_sec - seclast; int usec = nsec * 1000000 + tv.tv_usec - useclast; printf("%d usec " s "\n", usec); useclast = tv.tv_usec; seclast = tv.tv_sec; } while (0)
#else
#  define DBTIME_INIT ;
#  define DBTIME(s) ;
#endif

loadlevelreal * loadlevelreal::create(player * p, string default_dir,
				      bool inexact,
				      bool allow_corrupted_) {
  DBTIME_INIT;

  loadlevelreal * ll = new loadlevelreal();
  ll->cache = dircache::create(p);
  if (!ll->cache) return 0;
  
  DBTIME("created dircache");

  /* might want this to persist across loads, who knows... */
  /* would be good, except that the directory structure can
     change because of 'edit' or because of 'update.' (or
     because of another process!) */
  /* also, there are now multiple views because of corrupted flag */
  /* Nonetheless, a global cache with a ::refresh method
     and a key to call refresh would probably be a better
     user experience. */

  ll->allow_corrupted = allow_corrupted_;
  ll->plr = p;
  ll->sel = 0;
  ll->path = 0;

  ll->showstart = 0;
  ll->showlev = 0;
  ll->solstep = 0;
  ll->showsol = 0;
  ll->showidx = -1; /* start outside array */

  /* recover 'last dir' */
  string dir = default_dir;

  if (inexact) {
    if (lastdir != "") dir = lastdir;
    
    /* XXX should fall back (to argument?) if this fails;
       maybe the last directory was deleted? */
    do {
      if (ll->changedir(dir)) goto chdir_ok;
      printf("Dir missing? Up: %s\n", dir.c_str());
      dir = util::cdup(dir);
    } while (dir != ".");

    return 0;	

  chdir_ok:
    /* try to find lastfile in this dir, if possible */
    ll->select_lastfile();
  } else {
    if (!ll->changedir(dir, false)) return 0;
  }

  DBTIME("done");

  return ll;
}


/* prepend current path onto filename */
string loadlevelreal::locate(string filename) {
  
  stringlist * pp = path;
  
  string out = filename;
  while(pp) {
    if (out == "") out = pp->head;
    else out = pp->head + string(DIRSEP) + out;
    pp = pp -> next;
  }

  if (out == "") return ".";
  else return out;
}

int loadlevelreal::changedir(string what, bool remember) {

  DBTIME_INIT;

  // printf("changedir '%s' with path %p\n", what.c_str(), path);
  {
    stringlist * pp = path;
    while (pp) {
      /* printf("  '%s'\n", pp->head.c_str()); */
      pp = pp -> next;
    }
  }

  string where;

  /* Special case directory traversals. */
  if (what == "..") {
    if (path) {
      /* does the wrong thing after descending past cwd. */
      stringpop(path);
      where = locate("");
    } else return 0;
  } else if (what == ".") {
    /* no change, but do reload */
    // printf("special .\n");
    where = locate("");
  } else {
    /* n.b.
       if cwd is c:\escapex\goodesc,
       and path is ..\..\
       and we enter escapex,
       we should change to ..\,
       not ..\..\escapex.

       .. since we don't allow the path
       to descend beneath the 'root'
       (which is the cwd of escape), this
       scenario never arises.
    */

    where = locate(what);
    path = new stringlist(what, path);
  }

  DBTIME("cd got where");

  int n = dirsize(where.c_str());
  // printf("AFTER DIRSIZE\n");

  DBTIME("cd counted");

  /* printf("Dir \"%s\" has %d entries\n", where.c_str(), n); */

  if (!n) return 0;

  /* save this dir */
  if (remember) lastdir = where;

  selor * nsel = selor::create(n);

  nsel->botmargin = drawing::smallheight() + 16 ;

  nsel->below = this;

  nsel->title = helptexts(helppos);


  DBTIME("cd get index");

  /* get (just) the index for this dir, which allows us to
     look up ratings. note that there may be no index. */
  dirindex * thisindex = 0;
  cache->getidx(where, thisindex);


  DBTIME("cd got index");

  /* now read all of the files */

  /* init array */
  DIR * d = opendir(where.c_str());
  if (!d) return 0;
  dirent * de;

  int i;
  for(i = 0; i < n;) {
    de = readdir(d);
    if (!de) break;

    string ldn = locate(de->d_name);

    if (util::isdir(ldn)) {

      string dn = de->d_name;

      /* senseless to include current dir,
	 CVS and SVN dirs... */
      if (!(dn == "." ||
	    dn == "CVS" ||
	    dn == ".svn" ||
	    /* for now, don't even allow the user
	       to go above the home directory,
	       since we don't handle that
	       properly. */
	    (dn == ".." && !path))) {

	if (dn == "..") {
	  /* don't report completions for parent */
	  nsel->items[i].fname = dn;
	  nsel->items[i].isdir = 1;
	  nsel->items[i].solved = 0;
	  i++;
	} else {
	  int ttt, sss;
	  dirindex * iii = 0;

	  int dcp = SDL_GetTicks() + (PROGRESS_TICKS * 2);
	  if (cache->get(ldn, iii, ttt, sss, progress::drawbar,
			 (void*) &dcp)) {

	    /* only show if it has levels,
	       or at least has an index 
	       (in corrupted mode we show everything) */
	    if (iii || ttt || allow_corrupted) {
	    
	      nsel->items[i].fname = dn;
	      nsel->items[i].isdir = 1;
	      nsel->items[i].solved = sss;
	      nsel->items[i].total = ttt;
	      
	      /* no need to save the index, just the title */
	      nsel->items[i].name = iii?(iii->title):dn;
	      
	      i++;
	    }
	  }
	}
      }

    } else {

      string contents = util::readfilemagic(ldn, LEVELMAGIC);

      /* try to read it, passing along corruption flag */
      level * l = level::fromstring(contents, allow_corrupted);

      if (l) {
	string md5c = md5::hash(contents);


	typedef ptrlist<namedsolution> solset;
	
	/* owned by player */
	solset * sols = plr->solutionset(md5c);

	nsel->items[i].solved = 0;

	/* XXX this isn't incorrect, but we should ignore
	   solutions marked as bookmarks for performance
	   and sanity sake */
	if (sols) {
	  if (sols->head->sol->verified ||
	      level::verify(l, sols->head->sol)) {
	    sols->head->sol->verified = true;
	    nsel->items[i].solved = sols->head->sol->length;
	  } else if (sols->next) { 
	    /* first one didn't verify, but we should reorder
	       solutions so that one does, if possible */

	    solset * no = 0;
	    
	    while (sols) {
	      /* not trying bookmarks */
	      if (!sols->head->bookmark &&
		  level::verify(l, sols->head->sol)) {
		/* ok! create the new list with this
		   at the head. */

		namedsolution * ver = sols->head->clone();
		ver->sol->verified = true;

		/* get tail */
		sols = sols -> next;

		solset * yes = 0;
		
		/* put the current tail there, cloning */
		while (sols) {
		  solset::push(yes, sols->head->clone());
		  sols = sols -> next;
		}

		/* god this is annoying in C++ */
		while (no) {
		  solset::push(yes, no->head->clone());
		  no = no -> next;
		}

		solset::push(yes, ver);

		/* now save this reordering and succeed */
		plr->setsolutionset(md5c, yes);
		nsel->items[i].solved = ver->sol->length;

		goto solset_search_done;

	      } else {
		solset::push(no, sols->head);
		sols = sols -> next;
	      }
	    }

	    /* didn't find any, so free head;
	       solved stays 0 */
	    solset::diminish(no);

	  solset_search_done:;
	  }
	}


	nsel->items[i].isdir = 0;
	nsel->items[i].md5 = md5c;
	nsel->items[i].fname = de->d_name;
	nsel->items[i].name = l->title;
	nsel->items[i].author = l->author;
	nsel->items[i].corrupted = l->iscorrupted();
	nsel->items[i].sizex = l->w;
	nsel->items[i].sizey = l->h;
	nsel->items[i].lev = l;
	nsel->items[i].myrating = plr->getrating(md5c);
	nsel->items[i].speedrecord = 0;
	nsel->items[i].date = 0;
	nsel->items[i].owned = false;
	nsel->items[i].managed = thisindex && thisindex->webcollection();

	/* failure result is ignored, because the
	   votes are initialized to 0 anyway */
	if (thisindex) {
	  int ow;
	  thisindex->getentry(de->d_name, 
			      nsel->items[i].votes,
			      nsel->items[i].date,
			      nsel->items[i].speedrecord,
			      ow);
	  nsel->items[i].owned = plr->webid == ow;
	} 

	i++;
      }
    }
  }

  /* some of the entries we saw may have been
     non-escape files, so now shrink nsel */
  nsel->number = i;

  closedir(d);

  DBTIME("cd got everything");
  
  nsel->sort(getsort(sortby));

  DBTIME("cd sorted");

#if 0
  if (!nsel->number) {
    message::no(0, "There are no levels at all!!");
    return 0;
  }
#endif

  if (sel) sel->destroy();
  sel = nsel;

  if (!sel->number) {
    message::no(0, "There are no levels at all!!");

    /* FIXME crash if we continue  */
    exit(-1);
    /* could add a dummy entry? */
  }

  /* better not save our old show! */
  fix_show(true);

  return 1;
}

void loadlevelreal::draw() {

  sdlutil::clearsurface(screen, BGCOLOR);

  drawsmall ();
}

void loadlevelreal::drawsmall() {
  Uint32 color = 
    SDL_MapRGBA(screen->format, 0x22, 0x22, 0x44, 0xFF);

  int y = (screen->h - sel->botmargin) + 4 ;

  SDL_Rect dst;

  /* clear bottom */
  dst.x = 0;
  dst.y = y;
  dst.h = sel->botmargin - 4;
  dst.w = screen->w;
  SDL_FillRect(screen, &dst, BGCOLOR);

  /* now draw separator */
  dst.x = 8;
  dst.y = y;
  dst.h = 2;
  dst.w = screen->w - 16;
  SDL_FillRect(screen, &dst, color);

  if (sel->number == 0) {
    fon->draw(16, y + 8, WHITE "(" RED "No files!" POP ")" POP);
  } else if (sel->items[sel->selected].isdir) {
    fon->draw(16, y + 8, WHITE "(" BLUE "Directory" POP ")" POP);
  } else {
    if (!showlev) fix_show(true);
    drawing::drawsmall(y,
		       sel->botmargin,
		       color,
		       showlev,
		       sel->items[sel->selected].solved,
		       sel->items[sel->selected].fname,
		       &sel->items[sel->selected].votes,
		       sel->items[sel->selected].myrating,
		       sel->items[sel->selected].date,
		       sel->items[sel->selected].speedrecord);
  }
}

/* previously we only showed certain options when
   they were available. It might be good to do that
   still. */
const int loadlevelreal::numhelp = 2;
string loadlevelreal::helptexts(int i) {
  switch(i) {
  case 0:
    return 
      WHITE
      "Use the " BLUE "arrow keys" POP " to select a level and "
      "press " BLUE "enter" POP " or " BLUE "esc" POP " to cancel."
                     "      " BLUE "?" POP " for more options.\n"
      WHITE
      "Press " BLUE "ctrl-u" POP
      " to upload a level you've created to the internet.\n"
      
      WHITE
      "Press " BLUE "ctrl-r" POP " to adjust your rating of a level,"
      " or "   BLUE "ctrl-c" POP " to publish a comment.\n";

  case 1:
    return
      WHITE "Sorting options: " BLUE "ctrl-" 
            RED "d" POP "," 
            GREEN "s" POP ","
            BLUE "g" POP POP
            " sorts by global " RED "difficulty" POP ","
                                GREEN "style" POP ","
                                BLUE "rigidity" POP ".\n"

      WHITE BLUE "alt-" RED "d" POP "," GREEN "s" POP "," BLUE "g" POP POP
      " sorts by personal. "
      // deprecated.
      //      BLUE "ctrl-m" POP " manages solutions (upload/download/view).\n"

      WHITE BLUE "ctrl-a" POP " sorts alphabetically, " BLUE "ctrl-t" POP " by author. " 
            BLUE "ctrl-v" POP " shows unsolved levels first.";

  }

  return RED "help index too high";
}

#endif
