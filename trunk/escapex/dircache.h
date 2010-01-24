
#ifndef __DIRCACHE_H
#define __DIRCACHE_H

/* Loads the escape files in a directory (recursively)
   to check their solutions. Reports how many levels
   there are and how many are solved; caches this. Also
   loads the dirindex, if present (see dirindex.h). 

   Note: This is being replaced by leveldb for the 4.0
   series.
*/
   
#include "player.h"
#include "dirindex.h"

#define IGNOREFILE ".escignore"

/* abstract interface */
struct dircache {
  
  virtual void destroy () = 0;
  static dircache * create(player * p);
  virtual ~dircache();

  virtual void getidx(string dir, dirindex *& idx) = 0;

  /* lookup dir in the cache, sticking the result in idx.
     optionally provide a callback function for progress */
  virtual int get(string dir, dirindex *& idx, int & tot, int & sol,
		  void (*prog)(void * data, int n, int total, 
			       const string & subdir, const int tks) = 0,
		  void * prog_data = 0) = 0;

};

#endif
