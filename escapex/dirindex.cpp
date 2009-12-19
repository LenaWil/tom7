#include "dirindex.h"
#include "util.h"
#include "hashtable.h"
#include "extent.h"
#include "checkfile.h"

/* no reason for this to be particularly big,
   since it is limited to a single directory */
#define HASHSIZE 257

#define INDEX_IGNORED_FIELDS 6

#define INDEXMAGIC "ESXI"
#define INDEX2MAGIC "ESXi" /* now obsolete. but don't reuse */
#define INDEX3MAGIC "ESX!"

struct ra_entry {
  static unsigned int hash(string k) {
    return hash_string(k);
  }

  string key () {
    return filename;
  }
  string filename;
  ratestatus v;
  int date;
  int speedrecord;

  int owner;

  void destroy() { delete this; }

  ra_entry(string s, ratestatus vv, int d, int sr, int o) 
    : filename(s), v(vv), date(d), speedrecord(sr), owner(o) {}
  ra_entry() {}

};

struct di_real : public dirindex {
  
  static di_real * create ();

  virtual void writefile(string);

  virtual void destroy ();
  virtual ~di_real () {}
  virtual void addentry(string filename, ratestatus v, 
			int date, int speedrecord, int owner);

  /* read from disk */
  static dirindex * fromstring(string f);

  static void writeone(ra_entry * i, FILE * f);

  virtual bool getentry(string filename, ratestatus & v, int &, int &, int & o);

  virtual bool webcollection() { return isweb; }

  /* mapping filenames to ra_entry */
  hashtable<ra_entry, string> * tab;

  int isweb;

};

dirindex * dirindex::create() {
  return di_real::create();
}

bool di_real::getentry(string filename, ratestatus & v, int & d, int & sr, int & o) {
  ra_entry * e = tab->lookup(filename);
  if (e) {
    v = e->v;
    d = e->date;
    sr = e->speedrecord;
    o = e->owner;
    return true;
  } else return false;
}

di_real * di_real::create() {
  di_real * dr = new di_real();

  if (!dr) return 0;

  dr->title = "No name";
  dr->isweb = 0;
  dr->tab = hashtable<ra_entry, string>::create(HASHSIZE);

  if (!dr->tab) { dr->destroy(); return 0; }

  return dr;
}


bool dirindex::isindex(string f) {
  return (util::hasmagic(f, INDEXMAGIC) ||
	  util::hasmagic(f, INDEX3MAGIC));
}

dirindex * dirindex::fromfile(string f) {

  di_real * dr = di_real::create();

  if (!dr) return 0;

  /* read old index files */
  string iii = util::readfilemagic(f, INDEXMAGIC);

  /* chop off magic, then erase leading whitespace */
  if (iii != "") {
    dr->title = util::losewhitel(iii.substr
				 (strlen(INDEXMAGIC), 
				  iii.length() - 
				  strlen(INDEXMAGIC)));

    /* hashtable remains empty */
    return dr;
  } else {

    extent<di_real> de(dr);
    checkfile * cf = checkfile::create(f);
    
    if (!cf) return 0;
    
    extent<checkfile> fe(cf);

    /* check that it starts with v2 magic */
    string s;
    if (!cf->read(strlen(INDEX3MAGIC), s) || 
	s != INDEX3MAGIC) return 0;

    /* strip newline */
    if (!(cf->getline(s) && s == "")) return 0;

    if (!(cf->getline(dr->title))) return 0;

    { 
      for(int i = 0; i < INDEX_IGNORED_FIELDS; i ++)
	if (!cf->getline(s)) return 0; 
    }
    
    while(cf->getline(s)) {
      ra_entry * rr = new ra_entry;
      extent<ra_entry> re(rr);

      rr->filename = util::chop(s);
      rr->v.nvotes = stoi(util::chop(s));
      rr->v.difficulty = stoi(util::chop(s));
      rr->v.style = stoi(util::chop(s));
      rr->v.rigidity = stoi(util::chop(s));
      rr->v.cooked = stoi(util::chop(s));
      rr->v.solved = stoi(util::chop(s));
      rr->date = stoi(util::chop(s));
      rr->speedrecord = stoi(util::chop(s));
      rr->owner = stoi(util::chop(s));

      re.release ();
      dr->tab->insert(rr);
    }

    dr->isweb = 1;
    de.release ();
    return dr;
  }

}

void di_real::destroy() {
  if (tab) tab->destroy();
  delete this;
}

/* argument to hashtable::app */
void di_real::writeone(ra_entry * i, FILE * f) {
  fprintf(f, "%s %d %d %d %d %d %d %d %d %d\n",
	  i->filename.c_str(),
	  i->v.nvotes,
	  i->v.difficulty,
	  i->v.style,
	  i->v.rigidity,
	  i->v.cooked,
	  i->v.solved,
	  i->date,
	  i->speedrecord,
	  i->owner);
}

void di_real::writefile(string fname) {
  FILE * f = fopen(fname.c_str(), "wb");
  if (!f) return; /* XXX? */
		
  fprintf(f, INDEX3MAGIC "\n");

  /* single line gives title */
  fprintf(f, "%s\n", title.c_str());

  /* a few ignored lines */
  for(int i = 0; i < INDEX_IGNORED_FIELDS; i ++) fprintf(f, "\n");
  
  /* XXX sort first */
  
  /* then write each file */
  hashtable_app<ra_entry, string, FILE * >(tab, writeone, f);

  fclose(f);

}

void di_real::addentry(string f, ratestatus v, 
		       int date, int speedrecord, int owner) {
  tab->insert(new ra_entry(f, v, date, speedrecord, owner));
}
