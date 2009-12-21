

#include "escapex.h"
#include "level.h"
#include "sdlutil.h"
#include "load.h"
#include "md5.h"

#include <sys/stat.h>

#include "dirent.h"

#include "extent.h"
#include "util.h"
#include "dircache.h"
#include "progress.h"

#define HASHSIZE 31

struct direntry {
  string dir;

  dirindex * index;

  /* these counts include recursive traversals */
  int total;
  int solved;

  static unsigned int hash(string k) {
    return util::hash(k);
  }

  string key() { return dir; }
  void destroy() { 
    if (index) index->destroy(); 
    delete this; 
  }
  direntry(string d, dirindex * i, int t, int s) : dir(d), index(i), total(t), solved(s) {
    // printf("dircached %s\n", d.c_str());
  }
};

struct dcreal : public dircache {

  player * plr;
  
  hashtable<direntry, string> * table;

  static dcreal * create(player * p) {
    dcreal * dc = new dcreal();
    if (!dc) return 0;
    extent<dcreal> e(dc);
  
    dc->plr = p;

    dc->table = hashtable<direntry,string>::create(HASHSIZE);

    if (!dc->table) return 0;
 
    e.release();
    return dc;
  }

  virtual void destroy();

  virtual void getidx(string dir, dirindex *& idx);
  virtual int get(string dir, dirindex *& idx, 
                  int & tot, int & sol,
                  void (*prog)(void * d, int n, int total, 
                               const string &, const int) = 0,
                  void * pd = 0);
};

dircache::~dircache() {}

dircache * dircache::create(player * p) {
  return dcreal::create(p);
}

void dcreal::destroy () {
  table->destroy();
  delete this;
}

/* make sure it starts with ./ */
static string normalize(string dir) {
  if (dir == "") return ".";
  if (dir[0] != '.') return "." DIRSEP + dir;
  else return dir;
}

/* read index, but don't put in table */
void dcreal::getidx(string dir, dirindex *& idx) {
  dir = normalize(dir);
  idx = 0;
  string ifile = dir + (string)DIRSEP WEBINDEXNAME;
  idx = dirindex::fromfile(ifile);

  /* also try old name */
  if (!idx) idx = dirindex::fromfile(dir + (string)DIRSEP DIRINDEXNAME);
}

int dcreal::get(string dir, dirindex *& idx, int & tot, int & sol,
                void (*prog)(void * d, int n, int total, 
                             const string &, const int),
                void * pd) {
  // printf("get: %s\n", dir.c_str());

  dir = normalize(dir);
  // printf("normalized: %s\n", dir.c_str());

  direntry * de = table->lookup(dir);
  if (!de) {
    /* no entry. put it in the cache. */

    if (util::existsfile(dir + DIRSEP + IGNOREFILE)) {
      /* ignored dir */
      table->insert(new direntry(dir, 0, 0, 0));
      tot = 0; sol = 0; idx = 0;
      return 1;
    }

    /* printf("uncached and not ignored: '%s'\n", dir.c_str()); */

    /* calculuate size (for callback) */
    int total = 0;
    if (prog) total = dirsize(dir.c_str());
    /* printf("  DIRCACHE: %d total\n", total); */

    dirindex * didx;
    getidx(dir, didx);

    /* 
       if (didx) printf ("%s index: %s\n", ifile.c_str(), didx->title.c_str());
       else printf ("%s no index\n", ifile.c_str());
    */

    /* init array */
    DIR * d = opendir(dir.c_str());
    if (!d) return 0;
    dirent * dire;

    int ttt = 0, sss = 0;
    int num = 0;

    while( (dire = readdir(d)) ) {

      num ++;
      if (prog) prog(pd, num, total, dir, PROGRESS_TICKS);

      string dn = dire->d_name;
      string ldn = dir + (string)DIRSEP + dn;

      if (util::isdir(ldn)) {

        /* can't include . or .., dumb to
           include CVS and .svn */
        if (!(dn == "." ||
              dn == "CVS" ||
              dn == ".svn" ||
              dn == "..")) {

          int tsub, ssub;

          dirindex * iii_unused = 0;
          if (get(ldn, iii_unused, tsub, ssub, prog, pd)) {
            ttt += tsub;
            sss += ssub;
          }

        }

      } else {

        string contents = util::readfilemagic(ldn, LEVELMAGIC);

        level * l = level::fromstring(contents);

        if (l) {
          string md5c = md5::hash(contents);

          ttt ++;

          solution * s;
          if ((s = plr->getsol(md5c)) && (s->verified || level::verify(l,s))) {
            s->verified = true;
            sss ++;
          }

          l->destroy ();
        }
      }
    }

    closedir(d);

    table->insert(new direntry(dir, didx, ttt, sss));

    tot = ttt;
    sol = sss;
    idx = didx;

    return 1;

  } else { /* memoized */
    tot = de->total;
    sol = de->solved;
    idx = de->index;
    return 1;
  }
}
