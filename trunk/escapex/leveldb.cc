
/* n.b.: This code is not hooked up yet. You probably want to look at
   dircache.cc if you want to see what's actually going on in 3.0 series.
*/

#include "escapex.h"
#include "leveldb.h"
#include "dirent.h"
#include "md5.h"

/* levels loaded from disk and waiting to be added to the database */
struct levelwait {
  level * l;
  string filename;
  string md5;
  levelwait(level * le, string fn, string m) : l(le), filename(fn), md5(m) {}
};

static int nlevels = 0;
static lentry * all_levels = 0;

static player * theplayer = 0;

/* these are actually treated as stacks, but there's
   nothing wrong with that... */
/* files waiting to be added into the level database */
static stringlist * filequeue = 0;
/* loaded levels waiting to be added into the database
   (need to verify solutions), etc. */
static ptrlist<levelwait> * levelqueue = 0;

/* make room for one more in all_levels */
static void makeroom() {
  static int level_space = 0;
  
  /* then there's enough room! */
  if (nlevels < level_space) return;
  else {
    lentry * tmp = all_levels;
    level_space = 32 + (2 * level_space);
    all_levels = (lentry*)malloc(level_space * sizeof(lentry));

    for(int i = 0; i < nlevels; i ++) {
      all_levels[i] = tmp[i];
    }
    free(tmp);
  }
}

void leveldb::setplayer(player * p) {
  theplayer = p;
}

static lval getfield(const lentry * l, const lfield f) {
  switch(f) {
  case LF_TITLE: return lval(l->lev->title);
  case LF_AUTHOR: return lval(l->lev->author);
  case LF_WIDTH: return lval(l->lev->w);
  case LF_HEIGHT: return lval(l->lev->h);
  case LF_MD5: return lval(l->md5);
  case LF_DATE: return lval(l->date);
  case LF_SOLVED: return lval(l->solved);
  default: return lval::exn("unimplemented field");
  }
}

lval lexp::eval(const lentry * l) {
  switch(tag) {
  case LE_VALUE: return v;
  case LE_FIELD: return getfield(l, f);

  default: return lval::exn("unimplemented");
  }
}

/* XXX should enqueue here instead of doing it immediately */

/* this means add all files in this dir */
/* XXX should be recursive too, I guess */
void leveldb::addsourcedir(string s) {
  DIR * d = opendir(s.c_str());
  dirent * de;
  while ( (de = readdir(d)) ) {
    if (strcmp(".", de->d_name) &&
	strcmp("..", de->d_name)) {
      addsourcefile(de->d_name);
    }
  }
}

void leveldb::addsourcefile(string s) {
  filequeue = new stringlist(s, filequeue);
}


/* return true if progress made */
static bool workonqueues() {

  if (levelqueue) {

    levelwait * lw = ptrlist<levelwait>::pop(levelqueue);

    makeroom();
    
    all_levels[nlevels].id = nlevels;
    all_levels[nlevels].lev = lw->l;
    all_levels[nlevels].fname = lw->filename;
    all_levels[nlevels].md5 = lw->md5;

#if 0
    int date;
    int speedrecord;

    int nvotes;
    int difficulty;
    int style;
    int rigidity;
    int cooked;
    int solved;

    /* always owned by player; don't free */
    rating * myrating;
    bool owned;
#endif

    nlevels ++;
    return true;

  } else if (filequeue) {
    string s = stringpop(filequeue);

    /* XXX else could be a multilevel file, once we
       support those. */
    if (util::hasmagic(s, LEVELMAGIC)) {
      string c = readfile(s);
      level * l = level::fromstring(c, true);

      if (l) {
	string m = md5::hash(c);
	/* put on the level queue now */
	levelqueue = new ptrlist<levelwait>(new levelwait(l, s, m), levelqueue);
	return true;

      }
    }

    return true;
  } else return false;
}
