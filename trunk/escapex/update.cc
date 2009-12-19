
#include "update.h"
#include "extent.h"
#include "md5.h"
#include "util.h"
#include "textscroll.h"
#include "prompt.h"
#include "message.h"
#include "chars.h"
#include "upper.h"
#include "handhold.h"
#include "menu.h"

#include "client.h"

#define UNSUBMARKER "unsubscribed"
#define SHOWRATE 500

/* result of checkcollections */
enum ccresult {
  CC_FAIL, CC_OK,
};

enum selresult {
  SR_FAIL, SR_OK,
};

struct updatereal : public updater {

  static updatereal * create(player * p);

  updateresult update(string & msg);

  virtual void destroy() {
    tx->destroy();
    delete this;
  }

  virtual ~updatereal() {}

  virtual void draw();
  virtual void screenresize();

  void redraw();

  private:

  void say(string s) {
    if (tx) tx->say(s);
  }

  void sayover(string s) {
    if (tx) {
      tx->unsay();
      tx->say(s);
    }
  }

  player * plr;

  textscroll * tx;

  ccresult checkcolls(http * hh, 
		      stringlist *& fnames, 
		      stringlist *& shownames);

  selresult selectcolls(stringlist * fnames, 
			stringlist * shownames,
			stringlist *&, stringlist *&);

  void updatecoll(http * hh, string fname, string showname); 

};

/* version of toggle where toggling causes the
   subscription file to be written/removed */
struct subtoggle : public toggle {
  string fname;

  virtual inputresult key(SDL_Event e);
  virtual inputresult click(int x, int y);

  void docheck();

};

void subtoggle::docheck() {
    if (!checked) {

      /* try to subscribe */
      if (util::existsdir(fname)) {
	/* delete unsub file from dir */
	if (util::remove(fname + (string)DIRSEP + UNSUBMARKER)) {

	  checked = true;

	} else {

	  message::quick(0, (string)"Can't subscribe to " 
			 BLUE + fname + (string)POP " (remove unsub file)",
			 "Cancel", "", PICS XICON POP);

	}
      } else {
	/* create subscription (directory) */
	if (util::makedir(fname)) {
	  checked = true;
	  
	} else {
	  message::quick(0, (string)"Can't subscribe to " 
			 BLUE + fname + (string)POP " (can't make dir!!)",
			 "Cancel", "", PICS XICON POP);
	}
      }
    } else {
      /* try to unsubscribe */
    
      if (writefile(fname + (string)DIRSEP + UNSUBMARKER,
		    (string)"delete this file to resubscribe to " + fname + 
		    (string)"\n")) {

	checked = false;

      } else {
	message::quick(0, (string)"Can't unsubscribe to "
		       BLUE + fname + 
		       (string)POP " (can't make unsub file!)",
		       "Cancel", "", PICS XICON POP);
      }
    }
}

inputresult subtoggle::click(int, int) {
  docheck ();
  return inputresult (MR_UPDATED);
}

inputresult subtoggle::key(SDL_Event e) {
  int kk = e.key.keysym.sym;

  switch(kk) {
  case SDLK_RETURN:
  case SDLK_SPACE:
    docheck();
    return inputresult(MR_UPDATED);
  default: return menuitem::key(e);
  }

}

updater * updater :: create(player * p) {
  return updatereal::create(p);
}

updatereal * updatereal::create(player * p) {
  updatereal * uu = new updatereal();
  uu->tx = textscroll::create(fonsmall);
  uu->tx->posx = 5;
  uu->tx->posy = 5;
  uu->tx->width = screen->w - 10;
  uu->tx->height = screen->h - 10;
  uu->tx->vskip = 2;
  uu->plr = p;
  return uu;
}

void updatereal::redraw() {
  draw();
  SDL_Flip(screen);
}

/* return the available collections. 
   (by adding items to fnames, shownames)
*/
ccresult updatereal::checkcolls(http * hh, 
				stringlist *& fnames, 
				stringlist *& shownames) {
  /* first, grab COLLECTIONS. */

  string s;
  httpresult hr = hh->get(COLLECTIONSURL, s);

  if (hr == HT_OK) {
    /* parse result. see protocol.txt */
    int ncolls = stoi(util::getline(s));

    say((string)BLUE + itos(ncolls) + (string)" collection" +
	(string)((ncolls==1)?"":"s") + (string)":" POP);

    /* then, ncolls collections */
    while (ncolls--) {
      string line = util::getline(s);
      
      string fname = util::chop(line);
      int minv  = stoi(util::chop(line));
      string showname = line;

      int usable = stoi(VERSION) >= minv;

      if (fname == "") {
	say(RED "  collections file corrupt!!" POP);
	return CC_FAIL;
      }

      say((string)"  "YELLOW + fname + POP +
	  (string)(usable?" "GREEN:" "RED) +
	  itos(minv) + (string)POP" "BLUE + showname + POP);

      if (usable) {
	stringlist::push(fnames, fname);
	stringlist::push(shownames, showname);
      }
    }

    return CC_OK;

  } else {
    say("Message from server: " RED + s);
    say(RED "Unable to fetch collection list." POP);
    return CC_FAIL;
  }

}


/* invt: length(fnames) > 0 */
   
selresult updatereal::selectcolls(stringlist * fnames, 
				  stringlist * shownames,
				  stringlist *& subsf,
				  stringlist *& subss) {

  ptrlist<menuitem> * boxes = 0;

  okay ok;
  ok.text = "Update Now";

  cancel can;
  can.text = "Cancel";

  vspace v(16);

  stringlist * fnt = fnames;
  stringlist * snt = shownames;

  int n_entries = 0;

  while (fnt && snt) {
    subtoggle * b = new subtoggle();
    b->fname = fnt->head;
    b->question = snt->head;

    /* check subscribed: 
       for collection 'triage' we are
       subscribed if 'triage' subdir exists
       AND 'triage/unsubscribed' does not exist */
    if (util::existsdir(fnt->head)) {
      if (util::existsfile(fnt->head + (string)DIRSEP + UNSUBMARKER)) {
	b->checked = false;
      } else {
	b->checked = true;
      }
    } else {
      b->checked = false;
    }

    ptrlist<menuitem>::push(boxes, b);
    n_entries ++;

    fnt = fnt -> next;
    snt = snt -> next;
  }
  
  ptrlist<menuitem>::push(boxes, &v);
  ptrlist<menuitem>::push(boxes, &can);
  ptrlist<menuitem>::push(boxes, &ok);
  

  menu * mm = menu::create(this, 
			   "Select your collection subscriptions.", 
			   boxes, false);
  if (!mm) return SR_FAIL;

  resultkind res = mm->menuize();

  mm->destroy ();

  if (res == MR_OK) {
    /* process selections from 'boxes' list */

    subsf = 0;
    subss = 0;

    /* skip first three, the buttons */
    for (int z = 0; z < 3; z ++) {
      ptrlist<menuitem>::pop(boxes);
    }

    for(int i = 0; i < n_entries; i ++) {
      subtoggle * st = (subtoggle*)ptrlist<menuitem>::pop(boxes);
      if (st->checked) {
	stringlist::push(subsf, st->fname);
	stringlist::push(subss, st->question);
      }

      delete st;
    }

    return SR_OK;
  } else {
    return SR_FAIL;
  }

}

/* update a single collection "fname" using http connection hh. */
void updatereal::updatecoll(http * hh, string fname, string showname) {

  say("");
  say((string)"Updating " BLUE + showname + (string)POP " (" YELLOW +
      fname + (string)POP") ...");
  say("");

  string s;
  httpresult hr = hh->get((string)"/" + fname + (string) ".txt", s);

  if (hr == HT_OK) {
    /* parse result. see protocol.txt */

    string showname = util::getline(s);
    int minv = stoi(util::getline(s));
    int ndirs = stoi(util::getline(s));
    int nfiles = stoi(util::getline(s));
    string version = util::getline(s);    

    if (stoi(VERSION) < minv) {
      say(RED "?? Server inconsistent: This escape version is too old!" POP);
      /* fail */
      return;
    }

    /* create upper for this collection dir. */
    upper * up = upper::create(hh, tx, this, fname);

    if (!up) {
      message::bug(this, "couldn't create upper object?!");
      return;
    }

    extent<upper> eu(up);

    /* always save the root dir */
    up->savedir("", showname);

    say("ndirs: " + itos(ndirs));

    while(ndirs--) {
      string line = util::getline(s);
      
      string d = util::chop(line);
      string name = util::losewhitel(line);

      /* sanity check d. */
      if (d.length () < 1 || d[0] == '/' ||
	  d.find("..") != string::npos ||
	  d.find("//") != string::npos ||
	  /* yes, I mean one backslash */
	  d.find("\\") != string::npos) {
	message::no(this, "Bad directory name in collection: " RED + d);
	return;
      }
      
      /* on win32, rewrite / to \ */
      util::replace(d, "/", DIRSEP);

      up->savedir(d, name);
    }

    say("nfiles: " + itos(nfiles));

    int epoch = SDL_GetTicks ();

    /* then, ncolls collections */
    while (nfiles--) {
      string line = util::getline(s);

      /* printf("line: '%s'\n", line.c_str()); */
     
      string f = util::chop(line);
      string md = util::chop(line);

      /* sanity check f. This may be relative
	 to the current directory, so it is the
	 same condition as above */
      if (f.length () < 1 || f[0] == '/' ||
	  f.find("..") != string::npos ||
	  f.find("//") != string::npos ||
	  f.find("\\") != string::npos) {
	message::no(this, "Bad file name in collection: " RED + f);
	return;
      }
      

      ratestatus votes;

      votes.nvotes = stoi(util::chop(line));
      votes.difficulty = stoi(util::chop(line));
      votes.style = stoi(util::chop(line));
      votes.rigidity = stoi(util::chop(line));
      votes.cooked = stoi(util::chop(line));
      votes.solved = stoi(util::chop(line));

      int date = stoi(util::chop(line));
      int speedrecord = stoi(util::chop(line));
      int owner = stoi(util::chop(line));

      /* require file and md5, but not any of the voting stuff
	 (they will default to 0) */
      if (f != "" && md != "" && up->setfile(f, md, votes, 
					     date, speedrecord, owner)) {
	/* XXX change to sayover? */
	/* say((string)GREEN + f + (string)" " GREY + md + POP POP); */

      } else { 
	say((string)RED + f + (string)" " GREY + md + 
	    (string)POP " (error!)" POP);
	
	message::quick(this, (string)
		       RED "Unable to complete update of " BLUE + fname +
		       (string)POP"."POP, "Next", "", PICS XICON POP);

	return;

      }

      if (SDL_GetTicks() - epoch > SHOWRATE) {
	epoch = SDL_GetTicks ();
	redraw();
      }

    }

    /* XXX only say this if there were stray files */
    if (up->commit()) {
      say(GREEN "Success. Stray files moved to " BLUE "attic" POP"." POP);
    } else {
      say(RED "Committing failed. Stray files not deleted." POP);
    }

    /* succeed */
    return;

  } else {
    say(RED "Unable to fetch collection index!" POP);
    return;
  }

}

/* very similar to upgrade... maybe abstract it? */
updateresult updatereal::update(string & msg) {

  /* always cancel the hint */
  handhold::did_update();

  http * hh = client::connect(plr, tx, this);

  if (!hh) { 
    msg = YELLOW "Couldn't connect." POP;
    return UD_FAIL;
  }

  extent<http> eh(hh);

  stringlist * fnames = 0;
  stringlist * shownames = 0;

  switch (checkcolls(hh, fnames, shownames)) {
  case CC_OK:
    say("Got collections list.");
    break;
  default:
  case CC_FAIL:
    /* parse error? */
    message::quick(this, "Failed to get collections list.", 
		   "Cancel", "", PICS XICON POP);
    stringlist::diminish(fnames);
    stringlist::diminish(shownames);
    return UD_FAIL;
  }

  if (fnames == 0) {
    message::quick(this, 
		   "This version cannot accept any collections.\n"
		   "   You should try upgrading, though a new version\n"
		   "   might not be available yet for your platform.",
		   "Cancel", "", PICS XICON POP);
    /* fnames, shownames already empty */
    return UD_FAIL;
  }

  stringlist * subss, * subsf;

  
  selresult sr = selectcolls(fnames, shownames, subsf, subss);
  stringlist::diminish(fnames);
  stringlist::diminish(shownames);

  if (sr != SR_OK) return UD_FAIL;

  say(GREEN "Selected subscriptions.");

  /* now, for each subscribed collection, update it... */

  /* invt: subss and subsf are the same length */
  while (subss && subsf) {
    string ff = stringpop(subsf);
    string ss = stringpop(subss);

    updatecoll(hh, ff, ss);
  }

  /* XXX might want to give a fail message if any failed. */
  msg = GREEN "Level update complete.";
  say(msg);
  message::quick(this, "Level update complete.", "OK", "",
		 PICS THUMBICON POP);

  return UD_SUCCESS;
}

void updatereal::screenresize() {
  /* XXX resize tx */
}

void updatereal::draw() {
  sdlutil::clearsurface(screen, BGCOLOR);
  tx->draw();
}
