#ifndef __DIRINDEX_H
#define __DIRINDEX_H

/* a directory index provides meta-information about a directory in a
   managed collection (ie, triage). it includes:
     * a nice name (title) for the directory
     * global ratings for each level
     * dates that the levels were created (can be used to sort)
     * current speed records for each level
     * (your idea here)

   indices are written as index.esi in each managed directory. 

   Note: This is being replaced by leveldb for the 4.0 series.
*/

#include "util.h"

#define DIRINDEXNAME "index.esi"
#define WEBINDEXNAME "webindex.esi"

/* all as totals */
struct ratestatus {
  int nvotes;
  int difficulty;
  int style;
  int rigidity;
  int cooked;
  int solved;

  ratestatus() : nvotes(0), difficulty(0), style(0), 
       rigidity(0), cooked(0), solved(0) {}
};

struct dirindex {
  
  /* make an empty index, suitable for later writing to disk */
  static dirindex * create ();

  virtual void destroy () = 0;
  virtual ~dirindex () {}

  /* read from disk */
  static dirindex * fromfile(string f);

  static bool isindex(string f);

  virtual void writefile(string f) = 0;
  virtual void addentry(string filename, ratestatus v, 
			int date, int speedrecord, int owner) = 0;

  virtual bool getentry(string filename, ratestatus & v,
			int & date, int & speedrecord, int & owner) = 0;

  /* true if this is a managed collection */
  virtual bool webcollection() = 0;

  string title;

};

#endif
