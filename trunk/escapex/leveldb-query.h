
#ifndef __LEVELDB_QUERY_H
#define __LEVELDB_QUERY_H

#include <string>
#include <vector>

/* Queries against the level database (see leveldb.h for where they
   are used).
   
   This is annoying because C++ is not good at abstract syntax trees,
   but the basic idea is to form simple expressions over fields of
   levels (or their solutions, whatever) that describe filters (what
   levels to show) and sorts (what order to return them in). 

   Eventually we should have a parser for these so that advanced users
   can create their own queries in the interface. */

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

/* [argument codes]. v means value field is set,
   f means field field is set, numeric means that
   number of expression arguments are set. */
enum lexptag {
  /* [v] Inclusion of values in expressions */
  LE_VALUE,
  /* [f] The value of the field in the level of interest */
  LE_FIELD,
  /* [2] String expressions. */
  LE_CONCAT,
  /* [1] The argument string, with color values stripped */
  LE_NOCOLOR,
  /* [1] The argument string, in lowercase */
  LE_LOWERCASE,
  /* [1] True if the level has the exact tag */
  LE_HASTAG,
  /* [2] Boolean comparisons, which work on strings and ints. */
  LE_EQ,
  LE_LT,
  LE_LTE,
  LE_GT,
  LE_GTE,
  /* [2] Boolean expressions, which take bools. */
  LE_OR,
  LE_AND,
  /* [1] Boolean negation. */
  LE_NOT,
  /* [2] Numeric expressions, which work on ints. */
  LE_ADD,
  LE_SUB,
  LE_DIV,
  LE_MOD,
  LE_MUL,
  /* ... */
};

const int LE_MAXARGS = 2;

/* [argument codes]. s means uses the string field,
   f means float field, i is int, b is bool. */
enum lvaltag {
  /* [s] Can't evaluate; failcess */
  LV_EXCEPTION,
  /* [s] */
  LV_STRING,
  /* [f] */
  LV_FLOAT,
  /* [i] */
  LV_INT,
  /* [b] */
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
  explicit lval(int in) : tag(LV_INT), i(in) {}
  explicit lval(string st) : tag(LV_STRING), s(st) {}
  explicit lval(float fl) : tag(LV_FLOAT), f(fl) {}
  explicit lval(bool bo) : tag(LV_BOOL), b(bo) {}
  static lval exn(const string &s) {
    lval v;
    v.tag = LV_EXCEPTION;
    v.s = s;
    return v;
  }
};

/* An expression, like (LF_SOLVED > 0) AND (NOT (HASTAG "*tutorial")) */
struct lexp {
  lexptag tag;
  vector<lexp> args;

  lfield f;
  lval v;

  explicit lexp(lexptag t) : tag(t) {}

  lexp(lexptag t, const lexp &a) : tag(t) {
    args.push_back(a);
  }

  lexp(lexptag t, const lexp &l, const lexp &r) : tag(t) {
    args.push_back(l);
    args.push_back(r);
  }
};

struct lsort {
  /* The expression is evaluated to produce an integral, string,
     float, or boolean result. Each is sorted in ascending order
     (according to its type's < operator) unless descending = true. */
  lexp e;
  bool descending;
};

struct lquery { 
  /* returns boolean */
  lexp filter;

  /* Lexicographic. When we get to the tail, use an arbitrary but
     deterministic order. */
  vector<lsort> sortby;
};



#endif
