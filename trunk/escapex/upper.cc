
#include "upper.h"
#include "util.h"
#include "dirent.h"
#include "md5.h"
#include "chars.h"
#include "dirindex.h"

#define HASHSIZE 1021

struct oldentry {
  /* suitable for open() */
  string fname;

  bool deleteme;

  string key() {
    return fname;
  }

  static unsigned int hash(string k) {
    return util::hash(k);
  }  

  void destroy() { delete this; }

  oldentry(string f) : fname(f), deleteme(true) {}

};

struct contententry {
  
  string md5;
  string content;

  string key() {
    return md5;
  }

  /* endianness doesn't matter; we just have
     to be consistent */
  /* poorer than it could be because
     this string is in ASCII */
  static unsigned int hash(string k) {
    return *((unsigned int*) k.c_str());
  }

  void destroy () { delete this; }

  contententry(string con) : content(con) {
    md5 = md5::ascii(md5::hash(con));
  }

};

typedef hashtable<oldentry, string> oldtable;
typedef hashtable<contententry, string> contable;

struct upreal : public upper {

  static upreal * create(http *, textscroll *, drawable *, string);

  virtual ~upreal () {}

  virtual void destroy();
  virtual bool setfile(string f, string md, ratestatus votes, int, int, int o);
  virtual bool commit();

  virtual void savedir(string d, string index);

  void redraw() {
    if (below) {
      below->draw();
      SDL_Flip(screen);
    }
  }

  void say(string s, bool nodraw = false) {
    if (tx) {
      tx->say(s);
      if (!nodraw) redraw();
    }
  }

  void sayover(string s, bool nodraw = false) {
    if (tx) {
      tx->unsay();
      tx->say(s);
      if (!nodraw) redraw();
    }
  }

  /* for reporting progress */
  textscroll * tx;
  drawable * below;

  oldtable * olds;
  contable * contents;

  http * hh;

  /* the directory, like "official" */
  string dirname;

  /* list of new files: filename, md5 */
  stringlist * newlistf;
  stringlist * newlistm;

  /* list of saved dirs: dir, index.
     rep invt: these are the same length */
  stringlist * dirlistd;
  ptrlist<dirindex> * dirlisti;

  void init ();
  void insertdir(string d);

};

upper * upper::create(http * h, textscroll * t,
		      drawable * d, string f) {
  return upreal::create(h, t, d, f);
}

upreal * upreal::create(http * h, textscroll * t,
			drawable * d, string f) {
  upreal * ur = new upreal();
  ur->hh = h;
  ur->tx = t;
  ur->below = d;
  ur->dirname = f;

  ur->init();

  return ur;
}

void upreal::init () {
  /* initialize 'olds' and 'contents' */

  olds = oldtable::create(HASHSIZE);
  contents = contable::create(HASHSIZE);

  newlistf = 0;
  newlistm = 0;

  dirlistd = 0;
  dirlisti = 0;

  /* PERF: could download less if we
     included more directories in this
     search. But we don't want to delete
     from them! */
  /* loop over every file in dirname */

  insertdir(dirname);

}

void upreal::savedir(string d, string i) {

  /* XXX: could fail if d is a file. In this
     case we're sort of in trouble, since we
     can't move d without invalidating our own
     contable. */
  if (d != "") util::makedir(dirname + (string)DIRSEP + d);
  stringlist::push(dirlistd, d);

  /* XXX error checking? */
  dirindex * di = dirindex::create();
  di->title = i;
  ptrlist<dirindex>::push(dirlisti, di);

}

void upreal::insertdir(string src) {
  DIR * d = opendir(src.c_str());
    
  say((string)YELLOW"insertdir " + src + POP);

  struct dirent * de;
  while( (de = readdir(d)) ) {

    string basef = (string)de->d_name;
    string f = src + (string)DIRSEP + basef;

    /* say(f); */

    /* ignore some stuff */
    if (basef == "" /* ?? */ ||
	basef == "." ||
	basef == ".." ||
	basef == ".svn" ||
	basef == "CVS") continue;

    if(util::isdir(f)) {
      insertdir(f);
    } else {
      olds->insert(new oldentry(f));

      /* XXX use readfilesize,
	 where it won't read the file
	 unless it is small. (Someone
	 might stick big files in
	 managed dirs...)
      */
      string inside = readfile(f);
      contents->insert(new contententry(inside));
    }
  }

  closedir(d);
}


void upreal::destroy () {

  stringlist::diminish(newlistf);
  stringlist::diminish(newlistm);

  contents->destroy();
  olds->destroy();

  delete this;
}

bool upreal::setfile(string f, string md, ratestatus votes,
		     int date, int speedrecord, int owner) {

  say((string)"setfile(" + f + (string)", " 
      GREY + md + (string)POP ")", true);

  /* check that f is legal */
  if (f == "") return false;
  if (f[0] == DIRSEPC) return false;
  if (f.find("..") != string::npos) return false;

# ifdef WIN32
  /* XXX should just replace / with dirsep, unconditionally */
  /* on windows, replace / with \ */
  for(unsigned int j = 0; j < f.length(); j ++) {
    if (f[j] == '/') f[j] = '\\';
  }
# endif

  contententry * already = contents->lookup(md);

  /* if it's not already in the content hashtable,
     get it from the internet. */
  if (!already) {
    string mm;
    
    string first = md.substr(0, 2);
    string last  = md.substr(2, md.length() - 2);

    httpresult hr = 
      hh->get((string)"/" + dirname +
	      (string)"/" + first +
	      (string)"/" + last, mm);

    switch(hr) {
    case HT_OK: {
      contententry * nce = new contententry(mm);
      sayover((string)"(setfile) downloaded : " + nce->md5, true);

      if (nce->md5 != md) {
	say(RED "what I got differs from expected");
	say("written to last_got for debug");
	/* debug */
	writefile("last_got", mm);
	return false;
      }
      contents->insert(nce);
      break;
    }

    default:
      say((string)RED "unable to download");
      return false;
    }
  } else {
    sayover((string)"(setfile) already exists : "
	    BLUE + f + (string)POP" "
	    GREY + md + (string)POP, true);
  }

  /* if it's in the olds, mark it so
     that it won't be deleted */

  oldentry * existing = olds->lookup(dirname + DIRSEP + f);
  if (existing) existing->deleteme = false;

  /* put it in newlist */

  stringlist::push(newlistf, f);
  stringlist::push(newlistm, md);

  /* add its rating to the index.
     first, figure out what directory it lives in. */
  {
    string dd = util::pathof(f);
    string ff = util::fileof(f);
    /* we designate the current dir with the empty string, instead */
    if (dd == ".") dd = "";

    stringlist * dt = dirlistd;
    ptrlist<dirindex> * it = dirlisti;

    while (dt && it) {

      // printf("compare [%s] [%s]\n", dt->head.c_str(), dd.c_str());
      if (dt->head == dd) {
	it->head->addentry(ff, votes, date, speedrecord, owner);
	return true;
      }

      dt = dt -> next;
      it = it -> next;
    }
    /* XXX should fail if directory not found? */  
  }
    
  return true;
}

static void deleteif(oldentry * oe, int dummy_param) {
  if (oe->deleteme) {
    /* we can delete index files with proper magic. these are
       always overwritten with every update */
    if (dirindex::isindex(oe->fname)) {
      /* but if deletion fails (in use?), try moving */
      if (!util::remove(oe->fname))
	util::toattic(oe->fname);
    } else {
      util::toattic(oe->fname);
    }
  }
}

bool upreal::commit() {

  say(YELLOW " ======= " WHITE " commit phase " POP " ======= " POP);

  /* overwrite anything in newlist. */

  /* PERF optimization: don't do anything if
     content in oldf is the same as what
     we're going to write over it. this
     should be the common case... (to do this,
     store md5 in olds) */

  string nlf;
  string nlm;

  for(;;) {
    nlf = stringpop(newlistf);
    nlm = stringpop(newlistm);
    
    if (nlf == "") {
      if (nlm == "") break; /* done */
      say(RED "inconsistent lengths of nlf/nlm??" POP);
      return false;
    }

    /* everything is rooted within dirname */
    nlf = dirname + DIRSEP + nlf;

    /* Try removing before opening; Adam seems to think this
       improves our chances of success. */
    util::remove(nlf);
    FILE * a = util::fopenp(nlf, "wb");
    if (!a) {
      say((string)RED "couldn't write " + nlf + POP);
      /* XXX should continue writing, just not delete? */
      return false;
    }

    contententry * ce = contents->lookup(nlm);
    
    if (!ce) {
      say((string)RED "bug: md5 " BLUE "[" + nlm +
	  (string)"]" POP " isn't in table now??");

      fclose(a);
      return false;
    } else {
      if (1 != fwrite(ce->content.c_str(), ce->content.length(), 1, a)) {
	say((string)RED "couldn't write to " BLUE + nlf +
	    (string)POP " (disk full?)");

	fclose(a);
	return false;
      } else {
	/*
	  say((string)GREEN "wrote " BLUE + nlf +
	  (string)POP " <- " GREY + nlm + (string)POP" ok"); */
      }
    }

    fclose(a);

  }

  /* delete anything with delme=true in olds */
  hashtable_app(olds, deleteif, 0);

  /* create indices */
  /* We have the invt that length(dirlistd) =
     length(dirlisti) */
  while (dirlistd) {
    string d = stringpop(dirlistd);
    dirindex * i = ptrlist<dirindex>::pop(dirlisti);

    string f = 
      (d == "") 
      ? (dirname + (string)DIRSEP WEBINDEXNAME)
      : dirname + (string)DIRSEP + d + (string)DIRSEP WEBINDEXNAME;

    /* XXX check failure? */
    i->writefile(f);

    i->destroy();
  }

  /* FIXME prune empty dirs */

  return true;
}

