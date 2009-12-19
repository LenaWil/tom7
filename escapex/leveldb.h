
#ifndef __LEVELDB_H
#define __LEVELDB_H

#include "level.h"
#include "rating.h"

/* 
   New (4.0) level database. 
   
   This differs from the old level database (dircache) in many ways.
   Instead of being oriented around a filesystem, it simply collects
   together all of the levels available in a uniform way and allows
   different views of that set.

   This design has some advantages: For instance, it means that the
   levels need not be stored in one place in the filesystem. This
   is one step towards allowing a mutli-user installation of Escape,
   where the user's edited levels and downloaded levels reside in
   his home directory. Another major advantage is that levels can
   reside in multiple collections: The "letter series" can be in
   its own little collection but also in some broader collection of
   "good" levels.

   Each level has a set of tags, which are just strings. One easy
   query is to see all of the levels that have a certain tag. With
   this facility we can recreate the current setup: Each directory
   name ("triage"; "triage/veryfunny"; "official/tutorial") is a tag,
   and we only need some way of "tagging tags" (or giving a list of
   all of the directory-like tags somewhere). But this is not that
   important; I want to move away from the directory browser and
   subdirectories in particular are rather undermotivated.

   We'll want to distinguish some tags that the system treats
   specially. Each starts with the * character.
      *deleted    means that the level should be excluded from
                  most normal views by default
      *broken     means that the level should be excluded from
                  most normal views, and might not be solvable
      *tutorial   because the main menu treats these specially
      *net        downloaded from the internet (as opposed to
                  created locally). 

   
   Now collections on the server are just queries, perhaps
   with associated sub-queries (?). We could even allow trusted
   users to create collections by claiming a set of tags as their
   own and uploading a query to the server.

*/

struct lentry {
  /* identifier unique to this session.
     the same level (md5) might be in
     multiple files or in web collection
     and local, etc. */
  int id;
  /* owned by leveldb */
  level * lev;

  string fname;
  string md5;
  int date;
  int speedrecord;
  bool corrupted;

  int nvotes;
  int difficulty;
  int style;
  int rigidity;
  int cooked;
  int solved;

  /* always owned by player; don't free */
  rating * myrating;
  bool owned;

  /* XXX lastplay, playtime, lastedit, etc. */
};

/* fields in a lentry */
enum lfield {
  LF_ID,
  LF_MD5,
  LF_TITLE,
  LF_AUTHOR,
  LF_WIDTH,
  LF_HEIGHT,
  LF_DATE,
  LF_YEAR,
  LF_MONTH,
  LF_DAY,
  LF_VOTES,
  LF_SOLVED,
  LF_COOKED,
  LF_MYDIFFICULTY,
  LF_MYSTYLE,
  LF_MYRIGIDITY,
  LF_DIFFICULTY,
  LF_STYLE,
  LF_RIGIDITY,
};

enum lexptag {
  LE_VALUE,
  LE_FIELD,
  LE_NOCOLOR,
  LE_LOWERCASE,
  LE_EQ,
  LE_LT,
  LE_LTE,
  LE_GT,
  LE_GTE,
  LE_OR,
  LE_AND,
  LE_NOT,
  LE_ADD,
  LE_SUB,
  LE_DIV,
  LE_MOD,
  LE_MUL,
  LE_TRUE,
  LE_FALSE,
  /* ... */
};

const int LE_MAXARGS = 2;

enum lvaltag {
  LV_EXCEPTION, /* uses string */
  LV_STRING,
  LV_FLOAT,
  LV_INT,
  LV_BOOL,
};

struct lval {
  lvaltag tag;
  /* values */
  string s;
  float f;
  int i;
  bool b;
  lval() : tag(LV_EXCEPTION), s("uninitialized") {}
  lval(int in) : tag(LV_INT), i(in) {}
  lval(string st) : tag(LV_STRING), s(st) {}
  lval(float fl) : tag(LV_FLOAT), f(fl) {}
  lval(bool bo) : tag(LV_BOOL), b(bo) {}
  static lval exn(string s) {
    lval v;
    v.tag = LV_EXCEPTION;
    v.s = s;
    return v;
  }
};

struct lexp {
  lexptag tag;
  /* must be null if no args */
  lexp * args[LE_MAXARGS];

  lfield f;
  lval v;

  lexp(lexptag t, lexp * l = 0, lexp * r = 0) : tag(t) {
    args[0] = l;
    args[1] = r;
  }
  
  lval eval(const lentry * l);
};

struct lsort {
  lexp * e;
  bool reverse; /* if true, sort in descending order */

  /* null = arbitrary */
  lsort * next;
};

struct lquery { 
  /* returns boolean */
  lexp * filter;
  /* if null, arbitrary */
  lsort * sortby;
};


/* A queryresult consists of the result set and a function
   for incrementally updating it. */
struct queryresult {
  enum res { QUERY_DONE = 0, QUERY_TIMEUP = 1, QUERY_UPDATED = 2, };
  
  /* give current number of results */
  int nresults();
  lentry ** resultset;

  /* note that this may shuffle around the entries. 
     sets pct to the estimated current percent complete.
  */
  res update(float & pct);
};

struct leveldb {
  /* there is just one global level database. */

  /* set the player once before adding source dirs/files
     or issuing queries. */
  static void setplayer(player *);

  /* set the sources that the database will use */
  static void addsourcedir(string);
  static void addsourcefile(string);

  static queryresult * query(lquery);

};

#endif
