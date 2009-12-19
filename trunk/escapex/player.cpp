
#include "player.h"

#include "extent.h"
#include "chunks.h"
#include "checkfile.h"
#include "prefs.h"
#include "dirent.h"

#include "base64.h"
#include "md5.h"

#ifdef WIN32
# include <time.h>
#endif

#define HASHSIZE 512

#define PLAYER_MAGIC "ESXP"
#define PLAYERTEXT_MAGIC "ESPt"
#define PLAYER_MAGICS_LENGTH 4
#define SOLMARKER "-- solutions"
#define RATMARKER "-- ratings"
#define PREFMARKER "-- prefs"

/* give some leeway for future expansion */
#define IGNORED_FIELDS 8

namedsolution * namedsolution::clone() {
  return new namedsolution(sol->clone(), name, author, date, bookmark);
}

namedsolution::namedsolution() {
  name = "";
  sol = 0;
  author = "";
  date = 0;
  bookmark = false;
}

namedsolution::namedsolution(solution * s, string na, 
			     string au, int da, bool bm) {
  name = na;
  sol = s;
  author = au;
  date = da;
  bookmark = bm;
}

string namedsolution::tostring () {
  string solstring = sol->tostring ();

  return
    sizes(date) +
    sizes(name.length()) + name +
    sizes(author.length()) + author +
    sizes(solstring.length()) + solstring +
    sizes(bookmark ? 1 : 0);
}

namedsolution * namedsolution::fromstring (string s) {
  unsigned int idx = 0;
  if (idx + 4 > s.length()) return 0; int d = shout(4, s, idx);
  
  if (idx + 4 > s.length()) return 0; int nl = shout(4, s, idx);
  if (idx + nl > s.length()) return 0;
  string na = s.substr(idx, nl);
  idx += nl;
  
  if (idx + 4 > s.length()) return 0; int dl = shout(4, s, idx);
  if (idx + dl > s.length()) return 0;
  string de = s.substr(idx, dl);
  idx += dl;
  
  if (idx + 4 > s.length()) return 0; int sl = shout(4, s, idx);
  if (idx + sl > s.length()) return 0;
  string ss = s.substr(idx, sl);
  idx += sl;
  
  solution * so = solution::fromstring(ss);
  if (!so) return 0;
  
  bool bm;
  if (idx + 4 > s.length()) bm = false;
  else {
    int bl = shout(4, s, idx);
    idx += 4;
    bm = !!bl;
  }
  
  return new namedsolution(so, na, de, d, bm);
}

void namedsolution::destroy () {
  sol->destroy ();
}

int namedsolution::compare(namedsolution * l, namedsolution * r) {
  /* PERF */
  return l->tostring().compare(r->tostring());
}

typedef ptrlist<namedsolution> nslist;

struct hashsolsetentry {
  string md5;
  nslist * solset;
  static unsigned int hash(string k);
  string key() { return md5; }
  void destroy() { 
    while (solset) nslist::pop(solset)->destroy();
    delete this; 
  }
  hashsolsetentry(string m, nslist * s) : md5(m), solset(s) {}
  static int compare(hashsolsetentry * l, hashsolsetentry * r) {
    return l->md5.compare(r->md5);
  }
};

struct hashratentry {
  string md5;
  rating * rat;
  static unsigned int hash(string k);
  string key() { return md5; }
  void destroy() { rat->destroy(); delete this; }
  hashratentry(string m, rating * r) : md5(m), rat(r) {}
  static int compare(hashratentry * l, hashratentry * r) {
    return l->md5.compare(r->md5);
  }
};


struct playerreal : public player {

  void destroy ();

  static playerreal * create(string n);

  chunks * getchunks() { return ch; }

  solution * getsol(string md5);

  rating * getrating(string md5);
  
  void putrating(string md5, rating * rat);

  bool writefile();

  static playerreal * fromfile(string file);
  /* call with file already open with cursor
     after the player magic. (Also pass filename
     since the player remembers this.)
     caller will close checkfile */
  static playerreal * fromfile_text(string fname, checkfile *);
  static playerreal * fromfile_bin(string, checkfile *);

  /* XX this one is wrong now; it returns "levels solved"
     not total number of solutions */
  int num_solutions() { return sotable->items; }
  int num_ratings() { return ratable->items; }

  ptrlist<solution> * all_solutions();

  virtual ~playerreal() {};

  private:

  void deleteoldbackups();
  static string backupfile(string fname, int epoch);
  bool writef(string);
  bool writef_binary(string);
  bool writef_text(string);

  hashtable<hashsolsetentry, string> * sotable;
  hashtable<hashratentry, string> * ratable;

  virtual ptrlist<namedsolution> * solutionset(string md5);
  virtual void setsolutionset(string md5, ptrlist<namedsolution> *);

  virtual void addsolution(string md5, namedsolution * ns, bool def_candidate);
  virtual bool hassolution(string md5, solution * what);

  chunks * ch;

};

bool playerreal::hassolution(string md5, solution * what) {
  string whats = what->tostring();

  for (nslist * l = solutionset(md5); l; l = l -> next) {
    // printf(" %s == %s ?\n", base64::encode(whats).c_str(), (base64::encode(l->head->sol->tostring())).c_str());
    if (l->head->sol->tostring () == whats) return true;
  }

  return false;

}

ptrlist<solution> * playerreal::all_solutions() {
  ptrlist<solution> * l = 0;

  for(int i = 0; i < sotable->allocated; i ++) {
    ptrlist<hashsolsetentry> * col = sotable->data[i];
    while(col) {
      nslist * these = col->head->solset;
      while (these) {
	l = new ptrlist<solution>(these->head->sol, l);
	these = these -> next;
      }
      col = col -> next;
    }
  }
  return l;
}

/* XXX these two should be in some general util file ... */
/* endianness doesn't matter here */
unsigned int hashsolsetentry::hash(string k) {
  return *(unsigned int*)(k.c_str());
}

unsigned int hashratentry::hash(string k) {
  return *(unsigned int*)(k.c_str());
}

void playerreal::destroy() {
  sotable->destroy();
  ratable->destroy();
  if (ch) ch->destroy();
  delete this;
}

player * player::create(string n) {
  return playerreal::create(n);
}

playerreal * playerreal::create(string n) {
  playerreal * p = new playerreal();
  if (!p) return 0;
  extent<playerreal> e(p);
  
  p->name = n;
  
  p->sotable = hashtable<hashsolsetentry,string>::create(HASHSIZE);
  p->ratable = hashtable<hashratentry,string>::create(HASHSIZE);

  p->ch = chunks::create();

  p->webid = 0;
  p->webseqh = 0;
  p->webseql = 0;

  if (!p->sotable) return 0;
  if (!p->ratable) return 0;
  if (!p->ch) return 0;

  /* set default preferences */
  prefs::defaults(p);

  e.release();
  return p;
}

solution * playerreal::getsol(string md5) {
  nslist * l = solutionset(md5);
  /* first try to find a non-bookmark solution */
  for(nslist * tmp = l; tmp; tmp = tmp -> next) {
    if (!tmp->head->bookmark) return tmp->head->sol;
  }
  /* otherwise just return the first bookmark */
  if (!l) return 0;
  else return l->head->sol;
}

nslist * playerreal::solutionset(string md5) {
  hashsolsetentry * he = sotable->lookup(md5);

  if (he) return he->solset;
  else return 0;
}

/* maintain the invariant that if the list exists, it
   is non-empty */
void playerreal::setsolutionset(string md5, nslist * ss) {
  if (ss) {
    hashsolsetentry * he = sotable->lookup(md5);
    if (he) {
      nslist * old = he->solset;
      he->solset = ss;
      /* delete old */
      while (old) nslist::pop(old)->destroy();
    } else {
      sotable->insert(new hashsolsetentry(md5, ss));
    }
  } else {
    /* otherwise, we are removing it */
    sotable->remove(md5);
  }
}


rating * playerreal::getrating(string md5) {
  hashratentry * re = ratable->lookup(md5);
  
  if (re) return re->rat;
  else return 0;
}

void playerreal::addsolution(string md5, namedsolution * ns, bool def_candidate) {
  hashsolsetentry * he = sotable->lookup(md5);

  if (he && he->solset) {

    namedsolution * headsol = he->solset->head;

    /* always add, even if it's worse */
    if (def_candidate) {

      /* only if it doesn't already exist..? */
#     if 0
      for (ptrlist<namedsolution> * tmp = he->solset;
	   tmp; tmp = tmp -> next) {

      }
#     endif

      /* put it at end, so it doesn't take over
	 default */
      ptrlist<namedsolution>::push_tail(he->solset,
					ns->clone());

    /* XXX this code path is not used now */
    /* only added if it's better than the default, or
       if the default is a bookmark */
    } else if (ns->sol->length < headsol->sol->length ||
	       (!ns->bookmark) && headsol->bookmark) {
      /* replace */
      he->solset->head = ns->clone();
      headsol->destroy();
    } else {
      /* discard this solution */
    }

  } else {
    /* there's no solution set; create a new one. */
    namedsolution * nsmine = ns->clone();
    nslist * l = new nslist(nsmine, 0);

    sotable->insert(new hashsolsetentry(md5, l));
  }
}

void playerreal::putrating(string md5, rating * rat) {

  hashratentry * re = ratable->lookup(md5);

  if (re && re->rat) {
    /* overwrite */
    re->rat->destroy();
    re->rat = rat;
  } else ratable->insert(new hashratentry(md5, rat));

}

/* in seconds */
#define BACKUP_FREQ ((24 * (60 * (60 /* minutes */) /* hours */) /* days */) * 5)
#define N_BACKUPS 4

string playerreal::backupfile(string fname, int epoch) {
  return fname + ".~" + itos(epoch);
}

/* get rid of old backups, if any */
void playerreal::deleteoldbackups() {
  DIR * dir = opendir(".");
  if (!dir) return;

  /* XX must agree with backupfile */
  string basename = 
#   ifdef WIN32
        util::lcase(
#   else
	(
#   endif
	  fname + ".~");

  dirent * de;
  int n = 0;
  int oldest = (time(0) / BACKUP_FREQ) + 1 ;
  while ((de = readdir(dir))) {
    string f = 
#     ifdef WIN32
        util::lcase(
#     else
	(
#     endif
      de->d_name);

	if (f.substr(0, basename.length()) ==
	    basename) {
	  string sage = f.substr(basename.length(),
				 f.length() - basename.length());
	  int age = atoi(sage.c_str());
  
	  /* check that it's a valid number ... */
	  if (age && sage == itos(age)) {
	    /* printf ("saw '%s' with age %d\n", f.c_str(), age); */
	    n ++;
	    if (age < oldest) oldest = age;
	  }
	}
  } /* while */

  closedir(dir);

  if (n > N_BACKUPS) {
    
    string delme = basename + itos(oldest);
    if (util::existsfile(delme) && util::remove(delme)) {
      /* try deleting again */
      /* printf ("deleted backup #%d\n", oldest); */
      deleteoldbackups();
    }
  }
}

bool playerreal::writefile() {

  /* Back up the player file. */
  if (prefs::getbool(this, PREF_BACKUP_PLAYER)) {
    int epoch = time(0) / BACKUP_FREQ;
    
    /* did we already back up in this epoch? */
    string tf = backupfile(fname, epoch);
    if (!util::existsfile(tf)) {
      writef(tf);
 
    }
    deleteoldbackups();
  }

  /* anyway, always write the real file */
  return writef(fname);
}

/* now always write as text file */
bool playerreal::writef(string file) {
  return writef_text(file);
}

bool playerreal::writef_text(string file) {
  FILE * f = fopen(file.c_str(), "wb");

  if (!f) return 0;

  fprintf(f, "%s\n", PLAYERTEXT_MAGIC);
  fprintf(f,
	  "%d\n"
	  "%d\n"
	  "%d\n", webid, webseqh, webseql);

  /* write ignored fields; for later expansion... */
  for(int u = 0 ; u < IGNORED_FIELDS; u ++) fprintf(f, "0\n");
  
  fprintf(f, "%s\n", name.c_str());

  fprintf(f, SOLMARKER "\n");
  /* fprintf(f, "%d\n", sotable->items); */

  {
  for(int i = 0; i < sotable->allocated; i ++) {
    ptrlist<hashsolsetentry>::sort(hashsolsetentry::compare, sotable->data[i]);
    for(ptrlist<hashsolsetentry> * tmp = sotable->data[i]; 
	tmp; 
	tmp = tmp -> next) {
      fprintf(f, "%s * %s\n", md5::ascii(tmp->head->md5).c_str(),
	      /* assume at least one solution */
	      base64::encode(tmp->head->solset->head->tostring()).c_str());
      /* followed by perhaps more solutions marked with @ */
      /* sort them first, in place */
      nslist::sort(namedsolution::compare, tmp->head->solset->next);

      for(nslist * rest = tmp->head->solset->next;
	  rest;
	  rest = rest -> next) {
	fprintf(f, "  %s\n", 
		base64::encode(rest->head->tostring()).c_str());
      }
      /* end it (makes parsing easier) */
      fprintf(f, "!\n");
    }
  }
  }

  fprintf(f, RATMARKER "\n");
  /* fprintf(f, "%d\n", ratable->items); */

  /* ditto... */

  {
  for(int ii = 0; ii < ratable->allocated; ii ++) {
    ptrlist<hashratentry>::sort(hashratentry::compare, ratable->data[ii]);
    for(ptrlist<hashratentry> * tmp = ratable->data[ii]; 
	tmp; 
	tmp = tmp -> next) {
      fprintf(f, "%s %s\n",
	      md5::ascii(tmp->head->md5).c_str(),
	      base64::encode(tmp->head->rat->tostring()).c_str());
    }
  }
  }
  fprintf(f, PREFMARKER "\n");

  /* write chunks */
  /* ch->tostring() */
  fprintf(f, "%s\n", base64::encode(ch->tostring()).c_str());


  fclose(f);
  return 1;
}

player * player::fromfile(string file) {
  return playerreal::fromfile(file);
}

#define FF_FAIL(s) do { printf("Bad player: %s: %s\n", \
			       fname.c_str(), s);      \
		        return 0; } while(0)
// #define FF_FAIL(s) return 0;

playerreal * playerreal::fromfile_text(string fname, checkfile * cf) {

  playerreal * p = playerreal::create("");
  if (!p) FF_FAIL("out of memory?");
  p->fname = fname;
  extent<playerreal> ep(p);

  string s;

  /* strip newline after magic */
  if (!(cf->getline(s) && s == "")) FF_FAIL("newline after magic");

  if (!cf->getline(s)) FF_FAIL("no webid"); p->webid = stoi(s);
  if (!cf->getline(s)) FF_FAIL("no seqh");  p->webseqh = stoi(s);
  if (!cf->getline(s)) FF_FAIL("no seql");  p->webseql = stoi(s);

  /* ignored fields for now */
  for(int z = 0; z < IGNORED_FIELDS; z++) {
    if (!cf->getline(s)) FF_FAIL("ignored fields");
  }

  if (!cf->getline(p->name)) FF_FAIL("player name");

  /* expect solution marker now */
  if (!cf->getline(s) || s != SOLMARKER) FF_FAIL ("solution marker");

  /* now read solutions until -- ratings */

  for( ;; ) {
    string l;
    if (!cf->getline(l)) FF_FAIL ("expected solution");
    
    /* maybe this is the end? */
    if (l == RATMARKER) break;
    
    string mda = util::chop(l);
    string md;
    if (!md5::unascii(mda, md)) FF_FAIL (((string)"bad md5 " + mda).c_str());

    string next = util::chop(l);
    
    if (next == "*") {
      /* default first */
      string solstring = base64::decode(util::chop(l));
      namedsolution * ns = namedsolution::fromstring(solstring);
      if (!ns) FF_FAIL ("bad namedsolution");

      nslist * solset = new nslist(ns, 0);
      nslist ** etail = &solset->next;
      
      /* now, any number of other solutions */
      for(;;) {
	if (!cf->getline(l)) FF_FAIL ("expected more solutions");
	string tok = util::chop(l);
	if (tok == "!") break;
	else {
	  namedsolution * ns = namedsolution::fromstring(base64::decode(tok));
	  if (!ns) FF_FAIL ("additional solution was bad");
	  /* and append it */
	  *etail = new nslist(ns, 0);
	  etail = &((*etail)->next);
	}
      }
      
      /* add a whole solution set */
      p->sotable->insert(new hashsolsetentry(md, solset));

    } else {
      /* old style singleton solutions */
      string solstring = base64::decode(next);
      solution * sol = solution::fromstring(solstring);
      if (!sol) FF_FAIL ("bad oldstyle solution");
      namedsolution ns(sol, "Untitled", p->name, 0);
      p->addsolution(md, &ns, false);
      sol->destroy();
    }
  }

  /* already read rating marker */

  for( ;; ) {
    string l;
    if (!cf->getline(l)) FF_FAIL ("expected rating");

    if (l == PREFMARKER) break;

    string md = util::chop(l);
    if (!md5::unascii(md, md)) FF_FAIL ("bad rating md5");

    string ratstring = base64::decode(util::chop(l));
    rating * rat = rating::fromstring(ratstring);

    if (!rat) FF_FAIL ("bad rating");

    /* ignore rest of line */
    p->putrating(md, rat);
  }

  /* already read pref marker */

  string cs; 
  if (!cf->getline(cs)) FF_FAIL ("expected prefs");
  p->ch = chunks::fromstring(base64::decode(cs));

  if (!p->ch) FF_FAIL ("bad prefs");


  ep.release();
  return p;
}


playerreal * playerreal::fromfile(string file) {

  checkfile * cf = checkfile::create(file);
  if (!cf) return 0;
  extent<checkfile> ecf(cf);

  string s;
  if (!cf->read(PLAYER_MAGICS_LENGTH, s)) return 0;
  
  /* binary or text format? */
  if (s == PLAYER_MAGIC) return fromfile_bin(file, cf);
  else if (s == PLAYERTEXT_MAGIC) return fromfile_text(file, cf);
  else return 0;
}  

/* XXX obsolete -- eventually deprecate and disable this */
playerreal * playerreal::fromfile_bin(string fname, checkfile * cf) {

  playerreal * p = playerreal::create("");
  if (!p) return 0;
  p->fname = fname;
  extent<playerreal> ep(p);

  string s;
  int i;

  if (!cf->readint(p->webid)) return 0;
  if (!cf->readint(p->webseqh)) return 0;
  if (!cf->readint(p->webseql)) return 0;

  /* ignored fields for now */
  for(int z = 0; z < IGNORED_FIELDS; z++) {
    if (!cf->readint(i)) return 0;
  }
  
  if (!cf->readint(i)) return 0;
  if (!cf->read(i, p->name)) return 0;
  if (!cf->readint(i)) return 0;


  /* i holds number of solutions */
  while(i--) {
    string md5;
    int sollen;
    string solstring;
    if (!cf->read(16, md5)) return 0;
    if (!cf->readint(sollen)) return 0;
    if (!cf->read(sollen, solstring)) return 0;

    solution * sol = solution::fromstring(solstring);

    if (!sol) return 0;

    namedsolution ns(sol, "Untitled", p->name, 0);
    p->addsolution(md5, &ns, false);
    sol->destroy();
  }

  /* here allow old player files with no ratings
     at all. perhaps obsolete this some day. */
  if (!cf->readint(i)) {
    if (p->ch) p->ch->destroy();
    p->ch = chunks::create();
    ep.release();
    return p;
  }

  /* otherwise; new format: i is number of ratings */
  while(i--) {
    string md5;
    string rastring;
    if (!cf->read(16, md5)) return 0;
    if (!cf->read(RATINGBYTES,rastring)) return 0;
    rating * rat = rating::fromstring(rastring);

    if (!rat) return 0;
    p->putrating(md5, rat);
  }

  /* here allow old player files with no chunks
     at all. Caller should be calling prefs::defaults
     to fill in the missing prefs. */

  if (!cf->readint(i)) {
    ep.release();
    if (p->ch) p->ch->destroy();
    p->ch = chunks::create();
    return p;
  }

  /* otherwise, read the table */

  string cs; 
  if (!cf->read(i, cs)) return 0;
  chunks * cc = chunks::fromstring(cs);

  if (cc) {
    if (p->ch) p->ch->destroy();
    p->ch = cc;
  } else return 0;

  ep.release();
  return p;
}
