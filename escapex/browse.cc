
#include "escapex.h"
#include "level.h"
#include "sdlutil.h"
#include "browse.h"
#include "md5.h"

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

#include "menu.h"

#include "progress.h"

#ifdef LINUX
/* just used for debugging */
#  include <sys/time.h>
#endif

#if 0 // XXX

/* how frequently to make a move in solution playback */
#define LOADFRAME_TICKS 100
#define STEPS_BEFORE_SOL 5

struct llentry {
  /* Global level/collection information. */
  one_result lev;

  /* Denormalized other info? */
  static int height() { return fon->height; }
  string display(bool selected);
  void draw(int x, int y, bool sel);
  string convert() { return fname; }
};

struct browse_ : public browse {

  virtual void draw() {
    

  }

  virtual void destroy() {
    if (showlev) showlev->destroy();
    delete this;
  }

  virtual string selectlevel();
  
  static loadlevelreal * create(player * p, string dir, 
				bool inexact, bool ac);


 private:
  /* From constructor argument. */
  bool allow_corrupted;

  /* save query we performed. */
  static lquery lastquery;
  /* and last MD5 we selected */
  static string lastmd5;

  /* this for solution preview */
  /* Ticks to wait before starting the preview */
  Uint32 showstart;
  level * showlev;
  int solstep;
  solution * showsol;
  /* if this isn't the same as sel->selected,
     then we are out of sync. */
  int showidx;

  selor * sel;
  string loop();

  /* if possible, select the last file seen here */
  void select_lastfile();
  
  /* called a few times a second, advancing through
     a solution if one exists. */
  void step();
  void fix_show(bool force = false);
  void drawsmall ();

};

loadlevelreal::sortstyle loadlevelreal :: sortby = loadlevelreal::SORT_DATE;
string loadlevelreal :: lastdir;
string loadlevelreal :: lastfile;

loadlevel * loadlevel :: create(player * p, string dir,
				bool td, bool ac) {
  return loadlevelreal::create (p, dir, td, ac);
}

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


string loadlevelreal :: selectlevel () {
  return loop();
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

string loadlevelreal::loop() {

  sel->redraw();

  SDL_Event event;

  Uint32 nextframe = SDL_GetTicks() + LOADFRAME_TICKS;

  /* last recovery file */
  string lastrecover;

  for(;;) {
    SDL_Delay(1);

    Uint32 now = SDL_GetTicks();
  
    if (now > nextframe) {
      step (); 
      nextframe = now + LOADFRAME_TICKS;
      /* only draw the part that changed */
      drawsmall ();
      SDL_Flip(screen);
    }
  
    while (SDL_PollEvent(&event)) {

      if ( event.type == SDL_KEYDOWN ) {
	int key = event.key.keysym.sym;
	/* breaking from here will allow the key to be
	   treated as a search */

	switch(key) {
	case SDLK_DELETE: {
	  string file = 
	    sel->items[sel->selected].actualfile(path);

	  string md5 =
	    sel->items[sel->selected].md5;

	  if (sel->items[sel->selected].managed) {

	    /* inside a web collection; we must own it */
	    if (/* this should be a user class, not a specific define.. */
		plr->webid == SUPERUSER ||
		(sel->items[sel->selected].owned &&
		 plr->webid)) {
	      
	      label message;
	      message.text = 
		PICS TRASHCAN POP
		" Really delete level from web collection?";
	      label message2;
	      message2.text =
		GREY "    (moves it to the graveyard)";
	      
	      int IND = 2;
	      
	      string password;

	      textpassword pass;
	      pass.question = "Server password:";
	      pass.input = "";
	      pass.explanation =
		"The server password. If you don't know it, too bad!"; 

	      textbox desc(42, 7);
	      desc.indent = IND;
	      desc.question = "Message. " GREY "(recommended)" POP;
	      desc.explanation =
		"You can explain your deletion here.";
	      
	      vspace spacer((int)(fon->height * 1.5f));
	      vspace spacer2((int)(fon->height * 1.5f));
	      
	      okay ok;
	      ok.text = "Delete Level";
	      
	      cancel can;
	      can.text = "Cancel";
	      
	      ptrlist<menuitem> * l = 0;
	      
	      ptrlist<menuitem>::push(l, &can);
	      ptrlist<menuitem>::push(l, &ok);
	      ptrlist<menuitem>::push(l, &spacer);

	      if (!sel->items[sel->selected].owned)
		ptrlist<menuitem>::push(l, &pass);

	      ptrlist<menuitem>::push(l, &desc);
	      ptrlist<menuitem>::push(l, &spacer2);
	      ptrlist<menuitem>::push(l, &message2);
	      ptrlist<menuitem>::push(l, &message);

	      
	      /* display menu */
	      menu * mm = menu::create(0, "Really delete?", l, false);
	      resultkind res = mm->menuize();
	      ptrlist<menuitem>::diminish(l);
	      mm->destroy ();
	      
	      if (res == MR_OK) {
		
		/* ask server */
		string res;
		if (client::quick_rpc(plr, DELETE_RPC,
				      (string)"pass=" +
				      httputil::urlencode(pass.input) +
				      (string)"&id=" +
				      itos(plr->webid) + 
				      (string)"&seql=" +
				      itos(plr->webseql) +
				      (string)"&seqh=" +
				      itos(plr->webseqh) +
				      (string)"&md=" +
				      md5::ascii(md5) +
				      (string)"&text=" +
				      httputil::urlencode(desc.get_text()),
				      res)) {
		
		  message::quick(this, "Success!", "OK", "", PICS THUMBICON POP);

		} else {
		  message::no(this, "Couldn't delete: " + res);
		  sel->redraw ();
		  continue;
		}
	      } else {
		/* menu: cancel */
		sel->redraw ();
		continue;
	      }

	    } else {
	      message::no(this, 
			  "In web collections, you can only delete\n"
			  "   a level that you uploaded. "
			  "(marked " PICS KEYPIC POP ")\n");
	      sel->redraw ();
	      continue;
	    }

	  } else {
	    /* just a file on disk */
	    if (!message::quick(this,
				PICS TRASHCAN POP " Really delete " BLUE +
				file + POP "?",
				"Yes",
				"Cancel", PICS QICON POP)) {
	      sel->redraw ();
	      continue;
	    }
	  }

	  if (!util::remove(file)) {
	    message::no(this, "Error deleting file!");
	    sel->redraw ();
	    continue;
	  }

	  /* we've deleted, so we need to reload this dir. save
	     lastfile as the file after or before the one we just
	     deleted */
	  if (sel->selected + 1 < sel->number)
	    lastfile = sel->items[sel->selected + 1].fname;
	  else if (sel->selected - 1 >= 0)
	    lastfile = sel->items[sel->selected - 1].fname;
	  
	  changedir(".");
	  
	  select_lastfile();
	  fix_show(true);
	  sel->redraw ();
	  break;
	}

	  /* sorting options */
	case SDLK_t:
	case SDLK_n:
	case SDLK_s:
	case SDLK_d:
	case SDLK_g:
	case SDLK_a:
	case SDLK_e:
	case SDLK_v: {
	  int resort = 0;

	  /* XXX allow other sorts */
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    resort = 1;
	    switch (key) {
	    default:
	    case SDLK_n: sortby = SORT_DATE; break;
	    case SDLK_a: sortby = SORT_ALPHA; break;
	    case SDLK_v: sortby = SORT_SOLVED; break;
	    case SDLK_e: sortby = SORT_WEBSOLVED; break;

	    case SDLK_d: sortby = SORT_GD; break;
	    case SDLK_s: sortby = SORT_GS; break;
	    case SDLK_g: sortby = SORT_GR; break;

	    case SDLK_t: sortby = SORT_AUTHOR; break;

	    }
	  } else if (event.key.keysym.mod & KMOD_ALT) {
	    switch (key) {
	    default: sortby = SORT_ALPHA; break;
	    case SDLK_d: sortby = SORT_PD; break;
	    case SDLK_s: sortby = SORT_PS; break;
	    case SDLK_g: sortby = SORT_PR; break;
	    }
	    resort = 1;
	  }

	  if (resort) {
	    /* focus follows currently selected file */
	    lastfile = sel->items[sel->selected].fname;

	    sel->sort(getsort(sortby));
	    
	    select_lastfile();
	    sel->redraw();

	    continue;
	  } else break;
	}
	case SDLK_BACKSPACE:
	  /* might fail, but that's okay */
	  changedir("..");
	  sel->redraw();
	  continue;
	case SDLK_KP_PLUS:
	case SDLK_SLASH:
	case SDLK_QUESTION:
	  helppos ++;
	  helppos %= numhelp;
	  sel->title = helptexts(helppos);
	  sel->redraw ();
	  continue;

	case SDLK_m:
	  if ((event.key.keysym.mod & KMOD_CTRL) &&
	      !sel->items[sel->selected].isdir) {

	    if (sel->items[sel->selected].solved) {
	      /* ctrl-m: manage solutions */
	      
	      smanage::manage(plr, sel->items[sel->selected].md5, 
			      sel->items[sel->selected].lev);

	    } else message::no(this, "You must solve this level first.");

	    /* we probably messed this up */
	    fix_show (true);
	    sel->redraw();
	    continue;
	  } else break;
	  continue;
	case SDLK_c:
	  if ((event.key.keysym.mod & KMOD_CTRL) &&
	      !sel->items[sel->selected].isdir &&
	      sel->items[sel->selected].lev) {
	    /* ctrl-c: comment on a level */
	  
	    if (plr->webid) {

	      level * l = sel->items[sel->selected].lev;

	      lastfile = sel->items[sel->selected].fname;

	      string file = 
		sel->items[sel->selected].actualfile(path);
	  
	      FILE * f = fopen(file.c_str(), "rb");
	      if (!f) {
		message::bug(this, "Couldn't open file to comment on");
	    
	      } else {

		string md = md5::hashf(f);
		fclose(f);
	    
		/* This does its own error reporting */
		commentscreen::comment(plr, l, md);

	      }
	    } else {
	      message::no(this, "You must register with the server to comment.\n"
			  "   (Press " BLUE "R" POP " on the main menu.)");
	    }
	    sel->redraw();
	  } else break;
	  continue;

	case SDLK_r:
	  if ((event.key.keysym.mod & KMOD_CTRL) &&
	      !sel->items[sel->selected].isdir &&
	      sel->items[sel->selected].lev) {
	    /* ctrl-r: rate a level */

	    if (plr->webid) {
	  
	      level * l = sel->items[sel->selected].lev;

	      lastfile = sel->items[sel->selected].fname;

	      string file = 
		sel->items[sel->selected].actualfile(path);

	      /* XXX now in llentry, also comment */
	      FILE * f = fopen(file.c_str(), "rb");
	      if (!f) {
		message::bug(this, "Couldn't open file to rate");
	    
	      } else {

		/* first remove its rating. it will be
		   invalidated */
		sel->items[sel->selected].myrating = 0;
	    
		string md = md5::hashf(f);
		fclose(f);
				   
		ratescreen * rs = ratescreen::create(plr, l, md);
		if (rs) {
		  extent<ratescreen> re(rs);

		  rs->rate();
		} else {
		  message::bug(this, "Couldn't create rate object!");
		}

		/* now restore the rating */
		sel->items[sel->selected].myrating = plr->getrating(md);
		/* XX resort? */

	      }

	    } else {
	      message::no(this, 
			  "You must register with the server to rate levels.\n"
			  "   (Press " BLUE "R" POP " on the main menu.)");

	    }

	    sel->redraw();
	  } else break;
	  continue;
	case SDLK_0:
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    // XXX TODO: Should use menu, and prompt for whether we're trying
	    // to solve every level in the diretory, or just the selected one.
	    string recp = prompt::ask(this, "Recover solutions from file: ",
				      lastrecover);
	  
	    player * rp = player::fromfile(recp);

	    if (!rp) {
	      message::quick(this, 
			     "Couldn't open/understand that player file.",
			     "OK", "", PICS XICON POP);
	      sel->redraw ();
	      continue;
	    }

	    extent<player> erp(rp);

	    int nsolved = 0;

	    /* progress meter.. */
	    int pe = 0; // SDL_GetTicks() + (PROGRESS_TICKS * 2);

	    int total = 0;
	    {
	      for(int i = 0; i < sel->number; i ++) {
		if ((!sel->items[i].isdir) &&
		    (!sel->items[i].solved)) {
		  total ++;
		}
	      }
	    }

	    /* for each unsolved level, try to recover solution */
	    int done = 0;
	    string solveds;
	    for(int i = 0; i < sel->number; i ++) {
	      if ((!sel->items[i].isdir) &&
		  (!sel->items[i].solved)) {
		
		done++;
		
		/* check every solution in rp. */
		ptrlist<solution> * all = rp->all_solutions();

		/* we don't need to delete these solutions */
		int snn = 0;

		// XXX check for esc keypress
		while (all) {
		  solution * s = ptrlist<solution>::pop(all);

		  /* PERF verify does its own cloning */
		  level * l = sel->items[i].lev->clone();

		  solution * out;
		  
		  progress::drawbar((void*)&pe,
				    done, total, 
				    GREY "(" + itos(nsolved) + ") " POP
				    + sel->items[i].name + " " + 
				    GREY + "(sol #" + itos(snn) + ")"
				    "\n" 
				    ALPHA100 GREEN +
				    solveds);
		  
		  snn ++;

		  /* printf("try %p on %p\n", s, l); */
		  if (level::verify_prefix(l, s, out)) {

		    /* XX should be length of prefix that solves */
		    sel->items[i].solved = 1;
		    string af = sel->items[i].actualfile(path);

		    /* XXX PERF md5s are stored */
		    FILE * f = fopen(af.c_str(), "rb");
		    if (!f) {
		      message::bug(this, "couldn't open in recovery");
		      sel->redraw ();
		      continue;
		    }
		    string md5 = md5::hashf(f);

		    fclose(f);

		    /* extend progress msg */
		    {
		      if (solveds != "") solveds += GREY ", ";
		      solveds += GREEN ALPHA100 + l->title;
		      solveds = font::truncate(solveds, 
					       /* keep right side, not left */
					       -(
					       -1 + 
					       (screen->w /
						(fonsmall->width - fonsmall->overlap))));
		      /* force draw */
		      pe = 0;
		    }

		    /* save solution now */
		    {
		      namedsolution ns(out, "Recovered", plr->name, 
				       time(0), false);
		      plr->addsolution(md5, &ns);
		    }
		    nsolved ++;
		    out->destroy();

		    /* then don't bother looking at the tail */
		    ptrlist<solution>::diminish(all);
		  }

		  l->destroy();
		}
	      }
	    }


	    if (nsolved > 0) {

	      plr->writefile();

	    } else message::quick(this,
				  "Couldn't recover any new solutions.",
				  "OK", "", PICS EXCICON POP);


	    fix_show ();
	    sel->redraw();
	  } else break;
	  continue;
	case SDLK_u:
	  /* holding ctrl, has registererd */
	  if ((event.key.keysym.mod & KMOD_CTRL)) {
	    /* ctrl-u */
	    if (plr->webid) {

	      /* could show message if not solved */
	      if (!sel->items[sel->selected].isdir &&
		  sel->items[sel->selected].solved) {

		label message;
		label message2;
		label message3;
		label message4;
		label message5;
		label message6;
		message.text = 
		  PICS QICON POP
		  " Upload this level to the internet?";
		message2.text =
		  "   " GREY "Only do this when the level's really done." POP;

	      
		message3.text =
		  PICS EXCICON POP " " RED "Important" POP 
		  ": Only upload levels that are your own work!" POP;

		message4.text =
		  "   " GREY "(not copied from the web without permission)" POP;

		message5.text = 
		  "   By uploading, you agree to let anyone freely distribute";
		message6.text =
		  "   and/or modify your level.";

		int IND = 2;
	      
		textbox desc(42, 7);
		desc.indent = IND;
		desc.question = "Message. " GREY "(optional)" POP;
		desc.explanation =
		  "You can post a comment about the level you're uploading.";
	      
		vspace spacer((int)(fon->height * 0.8f));
	      
		okay ok;
		ok.text = "Upload Level";
	      
		cancel can;
		can.text = "Cancel";
	      
		ptrlist<menuitem> * l = 0;
	      
		ptrlist<menuitem>::push(l, &can);
		ptrlist<menuitem>::push(l, &ok);
		ptrlist<menuitem>::push(l, &spacer);
	      
		ptrlist<menuitem>::push(l, &desc);
		ptrlist<menuitem>::push(l, &spacer);

		ptrlist<menuitem>::push(l, &message6);
		ptrlist<menuitem>::push(l, &message5);
		ptrlist<menuitem>::push(l, &spacer);

		ptrlist<menuitem>::push(l, &message4);
		ptrlist<menuitem>::push(l, &message3);
		ptrlist<menuitem>::push(l, &spacer);

		ptrlist<menuitem>::push(l, &message2);
		ptrlist<menuitem>::push(l, &message);

	      
		/* display menu */
		menu * mm = menu::create(0, "Really upload?", l, false);
		resultkind res = mm->menuize();
		ptrlist<menuitem>::diminish(l);
		mm->destroy ();
	      
		if (res != MR_OK) {
		  sel->redraw();
		  continue;
		}

		/* XXX could detect certain kinds of annoying 
		   levels and warn... */

		upload * uu = upload::create();

		if (!uu) {
		  message::bug(this,
			       "Can't create upload object!");
		  sel->redraw();
		  continue;
		}
		extent<upload> eu(uu);

		/* save spot */
		lastfile = sel->items[sel->selected].fname;

		string file = 
		  sel->items[sel->selected].actualfile(path);

		/* don't bother with message; upload does it */
		switch(uu->up(plr, file, desc.get_text())) {
		case UL_OK:
		  break;
		default:
		  break;
		}
	      } else {
		message::no(this, 
			    "Can't upload dirs or unsolved levels.");
	      }
	    } else {
	      message::no
		(this, 
		 "You must register with the server to upload levels.\n"
		 "(Press " BLUE "R" POP " on the main menu.)");
	    }
	    sel->redraw();
	    continue;

	  } else break;
	default:
	  break;
	}
      }
    
      selor::peres pr = sel->doevent(event);
      switch(pr.type) {
      case selor::PE_SELECTED:
	if (sel->items[pr.u.i].isdir) {
	  /* XXX test if changedir failed, if so,
	     display message. but why would it
	     fail? */
	  /* printf("chdir '%s'\n", sel->items[pr.u.i].fname.c_str()); */
	  if (!changedir(sel->items[pr.u.i].fname)) {
	    message::quick(0, "Couldn't change to " BLUE +
			   sel->items[pr.u.i].fname,
			   "Sorry", "", PICS XICON POP);
	  }
	  /* printf("chdir success.\n"); */
	  sel->redraw();
	  break;
	} else {
	  string out = sel->items[pr.u.i].fname;
	  lastfile = out;
	  while (path) {
	    out = stringpop(path) + string(DIRSEP) + out;
	  }
	  return out;
	}
      case selor::PE_EXIT: /* XXX */
      case selor::PE_CANCEL:
	return "";
      default:
      case selor::PE_NONE:
	;
      }
    
    }

  } /* unreachable */

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
