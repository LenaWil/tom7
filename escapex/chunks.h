
#ifndef __CHUNKS_H
#define __CHUNKS_H

#include "escapex.h"
#include "util.h"

/* associative chunk database. */

typedef unsigned int uint;

/* contents of database */
enum chunktype { CT_INT, CT_BOOL, CT_STRING, };
struct chunk {
  chunktype type;
  uint key;

  string tostring();
  static chunk * fromstring(string);
  chunk(uint, int);
  chunk(uint, bool);
  chunk(uint, string);
  virtual ~chunk() {}

  /* only one will make sense, depending on type */
  int i;
  string s;
};

/* database itself */
struct chunks {

  /* create a blank db with no chunks */
  static chunks * create();

  /* revive marshalled chunks */
  static chunks * fromstring(string s);

  /* marshall to string */
  virtual string tostring();

  /* returns 0 if not present */
  virtual chunk * get(uint key);

  /* replace existing chunk, if present.
     takes ownership of chunk in any case */
  virtual void insert(chunk * data);

  virtual ~chunks() {}
  virtual void destroy();

  private:
  ptrlist<chunk> * data;
  static int sort(chunk * l, chunk * r);
  

};


#endif
