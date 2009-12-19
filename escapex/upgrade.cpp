
#include "upgrade.h"
#include "extent.h"
#include "md5.h"
#include "util.h"
#include "textscroll.h"
#include "prompt.h"
#include "message.h"
#include "chars.h"
#include "time.h"
#include "handhold.h"
#include "startup.h"

#include "client.h"

#ifdef WIN32
/* this will only exist on windows */
#  define REPLACE_EXE "replace.exe"
#endif

/* note: this has to be here because
   C has no way to pass on ... arguments
   to another function */
#ifdef WIN32
/* execl */
#  include <process.h>
#endif

/* chmod and symlink ops on posix */
#ifndef WIN32
#  include <sys/types.h>
#  include <sys/stat.h>
#  include <unistd.h>
#endif

enum curesult {
  /* can't upgrade */
  CU_FAIL, 
  /* can upgrade, query */
  CU_QUERY ,
  /* should upgrade, recommend */
  CU_RECOMMEND, 
  /* already at newest version */
  CU_NEWEST,
};

enum upresult {
  /* error downloading something. Everything is
     still fine, though, we just didn't upgrade. */
  UR_NODOWN,
  /* error replacing files.
     now escape may be in an inconsistent state. */
  UR_CORRUPT,
  /* ok. restart */
  UR_RESTART,
};

enum uptype { UT_FILE, UT_DELETE, UT_SYMLINK, };

struct upitem {
  uptype t;

  string filename;
  string dest;
  string tempfile;
};

typedef vallist<upitem> ulist;

struct upgradereal : public upgrader {

  static upgradereal * create(player * p);

  upgraderesult upgrade(string & msg);

  virtual void destroy() {
    tx->destroy();
    delete this;
  }

  virtual ~upgradereal() {}

  virtual void draw();
  virtual void screenresize();

  void redraw();

  private:

  void say(string s) {
    if (tx) tx->say(s);
  }

  void unsay() {
    if (tx) tx->unsay();
  }

  player * plr;

  curesult checkupgrade(http * hh, string & msg,
			ulist *& download, stringlist *& ok);

  upresult doupgrade(http * hh, string & msg,
		     ulist * upthese);

  textscroll * tx;

  friend struct ugcallback;

};


upgrader * upgrader :: create(player * p) {
  return upgradereal::create(p);
}

upgradereal * upgradereal::create(player * p) {
  upgradereal * uu = new upgradereal();
  uu->tx = textscroll::create(fon);
  uu->tx->posx = 5;
  uu->tx->posy = 5;
  uu->tx->width = screen->w - 10;
  uu->tx->height = screen->h - 10;
  uu->plr = p;
  return uu;
}

void upgradereal::redraw() {
  draw();
  SDL_Flip(screen);
}

/* false if file doesn't exist.
   otherwise, md5 is set to the md5 
   hash of its contents */
bool md5file(string f, string & md5) {
  FILE * ff = fopen(f.c_str(), "rb");
  if (!ff) return false;
  else {
    md5 = md5::hashf(ff);
    fclose(ff);
    return true;
  }
}

struct ugcallback : public httpcallback {
  upgradereal * that;
  /* XXX use SDL_Ticks or whatever; never time(0) */
  virtual void progress(int recvd, int total) {
    if (recvd > (last + 16384) ||
	ltime < time(0)) {
      if (that && that->tx) {
	that->tx->unsay();
	that->tx->say((string)GREEN + itos(recvd) + GREY "/" POP + 
		      itos(total) + POP);
	that->redraw();
      }
      last = recvd;
      ltime = time(0);
    }
  }
  ugcallback() : that(0), last(-1000) {
    ltime = time(0);
  }
  int ltime;
  int last;
};

/* download anything in 'upthese', replacing the current
   versions on disk. Modifies the 'temporary' fields in
   upthese. */
upresult upgradereal::doupgrade(http * hh, string & msg,
				ulist * upthese) {

  for(ulist * hd = upthese;
      hd;
      hd = hd -> next) {

    switch(hd->head.t) {
    case UT_FILE: {

      string fnodotdot = util::replace(hd->head.filename, "..", "@");

      string dl = (string)"/" + (string)PLATFORM +
	(string)"/" + util::replace(fnodotdot,
				    "/", "_");

      say ((string)"Downloading " GREEN + dl + (string) POP " ...");

      say("Connecting...");
      redraw();

      switch (hh->gettempfile(dl, hd->head.tempfile)) {
      case HT_OK:
	unsay();
	say ((string)"    ..." GREEN "OK: " + hd->head.tempfile + POP);
	/* good. */
	redraw();
	break;
      default:
	say((string) YELLOW "Download error: " + msg + POP);
	msg = (string)"Failed to download " GREEN + dl + POP;
	return UR_NODOWN;
      }
    
    }
      break;

      /* catch error early */
    case UT_SYMLINK:
#     ifdef WIN32
      message::bug(this, 
		   RED " Somehow got symlink upitem on win32");
      return UR_NODOWN;
#     else
      break;
#     endif
    default:
      /* don't need to do anything to prepare these */
      break;
    }
  }

  /* Now the 'tempfile' field is filled in for every file downloaded.

  This is the point of no return: If we don't succeed in replacing,
  deleting, and symlinking each upitem here, then the installation
  is possibly corrupt. */

  /* these hold srcs and dests of any files that
     couldn't be replaced while the program is
     running. */
  stringlist * failsrc = 0;
  stringlist * faildst = 0;
  bool incomplete = false;

  for(ulist * h = upthese;
      h;
      h = h -> next) {

    string tf = h->head.tempfile;

    /* the local destination */
    string local = util::replace(h->head.filename, "/", DIRSEP);

    if (h->head.t == UT_FILE) {

      if (util::remove(local)) {
	/* make sure directories exist */
	util::createpathfor(local);
	if (util::move(tf, local)) {
	  /* ok */
	  say((string)"Replaced " YELLOW  + local + POP);

#       ifndef WIN32 /* posix */
	  /* set executable */
	  if (local.length() >= 4 && 
	      local.substr(local.length() - 4, 4) ==
	      ".exe") {
	    chmod(local.c_str(), 
		  S_IRUSR | S_IWUSR | S_IXUSR |
		  S_IRGRP | S_IXGRP |
		  S_IROTH | S_IXOTH);
	  }
#       endif
	} else {
	  say((string) RED "Can't replace " YELLOW + local + POP POP);

	  stringlist::push(faildst, local);
	  stringlist::push(failsrc, tf);
	}
      } else {
	say((string) RED "Can't unlink " YELLOW + local + POP POP);

	stringlist::push(faildst, local);
	stringlist::push(failsrc, tf);
      }
    }
  }

  /* do symlinks if supported. 
     we already caught them and errored on win32 */
# ifndef WIN32 /* posix */
  for(ulist * hs = upthese;
      hs;
      hs = hs -> next) {

    /* not replacing slash char here, because posix */
    string src = hs->head.filename;
    string dst = hs->head.dest;

    if (hs->head.t == UT_SYMLINK) {
      
      /* first remove anything, if there.
         since we're in posix, we don't need
	 to be sneaky about this. */

      util::createpathfor(src);
      /* XXX should also remove dirs? */
      if (!util::remove(src)) {
	say((string) RED "Can't unlink " YELLOW + src + 
	    POP " for symlink." POP);
        /* XXX ought try several prefixes in case this has happened before */
	if (!rename(src.c_str(), (src + ".deleteme").c_str ())) {
	  say((string) RED "Can't rename it either!");
	  incomplete = true;
	} else {
	  symlink(dst.c_str(), src.c_str());
	  say(src + GREEN " " LRARROW " " POP + dst);
	}
      } else {
	symlink(dst.c_str(), src.c_str());
	say(src + GREEN " " LRARROW " " POP + dst);
      }

    }
  }
# endif

  for(ulist * hr = upthese;
      hr;
      hr = hr -> next) {

    string todel = 
      util::replace(hr->head.filename, "/", DIRSEP);

    if (hr->head.t == UT_DELETE) {
      if (util::remove(todel)) {
	say((string)PICS TRASHCAN POP " " GREEN + todel + POP);
      } else {
	say((string) RED "Can't unlink " YELLOW + todel + POP POP);
	incomplete = true;
      }
    }
  }


  /* invt: failsrc, faildst are same length */
  if (failsrc) {

#   ifdef WIN32

    message::quick(this, "we need to do a trick to replace some files.",
		   "ok", "");
    /* XXX this comment is wrong now; I use replace.exe */
    /* On Windows 98, we need to do something special, because an
       executable cannot write to or remove itself. 

       The plan is this: rename the downloaded executable
       to something.exe. (Suppose the running exe is called
       self.exe)
	 
       ..      execafter     src         dst        src     dst
       exec something.exe self.exe something.exe tmp.dll sdl.dll
	 
       something will overwrite self, then
	 
       exec self.exe -upgraded

       and then the new self will say, "Upgrade complete!"
	 
    */

    int nmoves = failsrc->length();

    const char ** spawnargs = 
      (const char **) malloc(sizeof (char *) *
			     ((nmoves * 2) + 1 /* argv[0] */ 
			      + 1 /* execafter */
			      + 1 /* terminating 0 */));
    
    spawnargs[0] = REPLACE_EXE;
    spawnargs[1] = startup::self.c_str();

    int ii = 2;
    while(failsrc) {
      string ss = stringpop(failsrc);
      string dd = stringpop(faildst);
      spawnargs[ii++] = strdup(ss.c_str());
      spawnargs[ii++] = strdup(dd.c_str());

      say((string)"Will move " GREEN + ss +
	  (string)POP " to " GREEN + dd + POP);

    }

    spawnargs[ii++] = 0;

    for(int z = 0; z < ii; z++) {
      say((string)"[" YELLOW + itos(z) + (string)POP"] " +
	  (string)(spawnargs[z]?spawnargs[z]:"(null)"));
    }

    message::quick(this, "Escape will now restart.",
		   "OK", "");


    spawnv(_P_OVERLAY, 
	   REPLACE_EXE,
	   spawnargs);

    /* No return */

    message::bug(this,
		 "roundabout exec technique failed");
    return UR_CORRUPT;

#   else /* not win32 */

    incomplete = true;

#   endif
  }


  if (incomplete) {
    message::quick(this, "one or more files could not be "
		   "removed/moved/linked.",
		   "upgrade failed!", "", PICS XICON);
    return UR_CORRUPT;
  } else return UR_RESTART;
}

/* download and ok should not contain anything */
curesult upgradereal::checkupgrade(http * hh, 
				   string & msg,
				   ulist *& download,
				   stringlist *& ok) {
  /* start by checking for new versions of escape itself. */
  string s;
  say("Connecting...");
  httpresult hr = hh->get(UPGRADEURL, s);
  if (hr == HT_OK) {
    /* parse result. see protocol.txt */
    int nfiles     =    stoi(util::getline(s));
    int oldest     =    stoi(util::getline(s));
    int recom      =    stoi(util::getline(s));
    int current    =    stoi(util::getline(s));
    string name    =         util::getline(s);
    /* then, nfiles files */

    say("Got upgrade information:");
    say((string)"      oldest supported: " BLUE + itos(oldest) + POP);
    say((string)"   recommend threshold: " BLUE + itos(recom) + POP);
    say((string)"       current version: " BLUE + itos(current) +
	(string)" " POP "\"" BLUE + name + (string) POP "\"");

    download = 0;
    ok = 0;

    /* XXX distinguish different types of upgrade lines */
    for(int j = 0; j < nfiles; j ++) {
      string fl = util::getline(s);
      /* filename */
      string fi = util::chop(fl);
      string lfi = util::replace(fi, "/", DIRSEP);
      
      /* encodings (ignored) */
      util::chop(fl);
      /* md5 */
      string md = util::chop(fl);
      /* ignore remainder of fl for now ... */

      if (fi == "" || md == "") {
	say(RED "UPGRADE list appears to be corrupt (empty filename/md5)");
	return CU_FAIL;
      }

      /* md might be md5, or another special command. */

      if (md[0] == '-' && md[1] == '>') {
	/* symlink */
#       ifdef WIN32	
	  message::quick(this,
			 RED"OOPS!" POP " Can't make symlinks on win32. "
			 "Upgrade file is broken?", "oops", "");
	  return CU_FAIL;
#       else
	  string dst = md.substr(2, md.length() - 2);

	  char buf[1024];
	  /* readlink does not put 0 at end (?) */
	  memset(buf, 0, 1024 * sizeof(char));
	  int n = readlink(lfi.c_str(), buf, 1023);

	  /* if there's a link and it has the right thing
	     in it, we're done. */
	  if (n < 0 ||
	      (string)(char*)(&buf) != dst) {
	    /* bad */
	    say(font::pad(fi, 16) + (string)RED " " LRARROW " " POP WHITE
		+ dst + (string) POP RED " wrong" POP);

	    upitem uu;
	    uu.t = UT_SYMLINK;
	    uu.filename = fi;
	    uu.dest = dst;
	    ulist::push(download, uu);
	  } else {
	    say(font::pad(fi, 16) + (string)GREY " " LRARROW " "
		+ dst + (string) POP GREEN " ok" POP);
	  }

#       endif
      } else if (md[0] == '*') {
	/* delete */
	if (util::existsfile(lfi)) {
	  say(font::pad(fi, 16) + 
	      (string)RED " (" PICS TRASHCAN POP ")" POP);
	  upitem uu;
	  uu.t = UT_DELETE;
	  uu.filename = fi;
	  ulist::push(download, uu);
	} else {
	  say(font::pad(fi, 16) + (string)GREY " (absent)" POP
	      GREEN " ok" POP);
	}
      } else {
	string nowmd;
	if (md5file(lfi, nowmd) &&
	    md == md5::ascii(nowmd)) {
	  stringlist::push(ok, fi);
	  say(font::pad(fi, 16) + (string)GREY " " + md + 
	      (string) GREEN " ok");
	} else {
	  upitem uu;
	  uu.t = UT_FILE;
	  uu.filename = fi; 
	  ulist::push(download, uu);

	  say(font::pad(fi, 16) + (string)WHITE " " + md + 
	      (string) RED " wrong: " POP GREY + md5::ascii(nowmd));
	}
      }

    }
    
    if (download != 0) {
      if (atoi(VERSION) < oldest) {
	stringlist::diminish(ok);
	ulist::diminish(download);
	return CU_FAIL;
      }

      if (atoi(VERSION) < recom) {
	msg = BLUE "Upgrade recommended!" POP;
	return CU_RECOMMEND;
      } else {
	msg = BLUE "Upgrade optional." POP;
	return CU_QUERY;
      }

    } else {
      msg = BLUE "All files are up to date." POP;
      return CU_NEWEST;
    }

  } else {
    say("Message from server: " RED + s);
    msg = YELLOW "Error contacting upgrade server." POP;
    return CU_FAIL;
  }
}

upgraderesult upgradereal::upgrade(string & msg) {

  /* no matter what, cancel the hint to upgrade */
  handhold::did_upgrade ();

  http * hh = client::connect(plr, tx, this);

  if (!hh) { 
    msg = YELLOW "Couldn't connect." POP;
    return UP_FAIL;
  }

  extent<http> eh(hh);

  /* install upgrader */
  ugcallback cb;
  cb.that = this;
  hh->setcallback(&cb);

  ulist * download;

  /* XXX what is the point of the 'ok' list? */
  stringlist * ok;
  string upmsg;
  switch (checkupgrade(hh, upmsg, download, ok)) {
  case CU_FAIL:
    say((string)"Upgrade fail: " + upmsg);
    /* lists will be empty */
    message::quick(this, "Couldn't get upgrade info.", 
		   "Cancel", "", PICS XICON POP);
    break;

  case CU_NEWEST:
    /* XXX show md5s or sizes or something cool. */
    say((string)"Upgrade: " + upmsg);
    stringlist::diminish(ok);
    ulist::diminish(download);
    message::quick(this, "Already at newest version!", "OK", "");
    break;

  case CU_QUERY:
  case CU_RECOMMEND: {

    say("Upgrade: " BLUE "The following files are not up-to-date:" POP);
    for(ulist * tmp = download;
	tmp;
	tmp = tmp -> next) {
      /* XXX print delete, symlink, etc */
      say((string)"  " YELLOW + tmp->head.filename + POP);
    }

    int doit = message::quick(this, "Upgrade Escape now?", 
			      "Yes", "No", PICS QICON POP);

    if (doit) {

      string upgmsg;
      upresult up;
      up = doupgrade(hh, upmsg, download);
      stringlist::diminish(ok);
      ulist::diminish(download);
      switch(up) {

      case UR_CORRUPT:
	message::quick(this, YELLOW "Oops! " POP 
		       "The installation failed and may be corrupted.", 
		       "Exit", "", PICS SKULLICON);
	return UP_EXIT;
	break;
	
      case UR_NODOWN:
	message::quick(this, "Upgrade failed. Try again later.",
		       "Oh well!", "", PICS XICON);
	return UP_FAIL;
	break;

      case UR_RESTART:
	message::quick(this, "Upgrade succeeded! "
		       "You must exit and start Escape again.", 
		       "Exit", "", PICS THUMBICON POP);
	return UP_EXIT;
	break;
      }

    }

    break;
  }
  }

  return UP_FAIL;
}

void upgradereal::screenresize() {
  /* XXX resize */
}

void upgradereal::draw() {
  sdlutil::clearsurface(screen, BGCOLOR);
  tx->draw();
}
