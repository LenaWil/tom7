
#ifndef __LEVELDB_H
#define __LEVELDB_H

#include "level.h"
#include "rating.h"
#include "leveldb-query.h"

#include <vector>

// #include "SDL_mutex.h"

/* 
   New (4.0) level database. (Not yet finished or being used.)

   The level database keeps track of all of the levels and
   collections that the game knows about.

   This differs from the old level database (dircache) in many ways.
   Instead of being oriented around a filesystem, it simply collects
   together all of the levels available in a uniform way and allows
   different views of that set.

   This design has some advantages: For instance, it means that the
   levels need not be stored in one place in the filesystem. This
   is one step towards allowing a mutli-user installation of Escape,
   where the user's edited levels and downloaded levels reside in
   his home directory. Another major advantage is that levels can
   live in multiple collections: The "letter series" can be in
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

   Collections are just queries with some metadata. These can be
   tagged, so that they can be retrieved by other collections.

   We might some day allow trusted users to create collections by
   claiming a set of tags as their own and uploading a query to the
   server.

   The level browser is still single-threaded, but the database is
   designed around a workqueue interface, where loading can be done
   incrementally. This allows for a snappier view of levels.
*/

/* A query returns a vector of results, which can be levels or
   collections. */

struct res_level;
struct res_query;
struct one_result {
  /* Give the actual subclass, or return null if it isn't. */
  virtual const res_level * is_level() const { return NULL; }
  virtual const res_query * is_query() const { return NULL; }
};

/* This represents everything global we know about a level. Facts
   about this player's relationship with the level are stored in the
   playerdb. */
struct res_level : public one_result {
  virtual const res_level * is_level() const { return this; }
  res_level() : lev(0), date(0), speedrecord(0), nvotes(0), difficulty(0),
    style(0), rigidity(0), cooked(0), solved(0), owned_by_me(false) {}

  string md5;

  /* The level may appear in multiple places.

     For now, these are just filenames. When we some
     day support multi-level files, this can be something 
     like /games/escape/2008pack.esz/001.esx */
  vector<string> sources;

  vector<string> tags;

  /* The parsed level, which is owned by leveldb and should be treated
     as read-only. Note that if we know about a level (like ratings
     from the index) but never found it on disk, this will be NULL and
     the sources vector will be empty. */
  const level *lev;

  /* Date of (first) birth. */
  int date;
  
  /* Number of moves in fastest known solution(s) */
  int speedrecord;

  /* Global ratings. */
  int nvotes;
  int difficulty, style, rigidity, cooked, solved;

  /* Always owned by player; don't free. */
  // rating * myrating;
  bool owned_by_me;

  // XXX convenience accessors like getrating, getdefaultsolution
  // etc. that consult the canonical locations for these.

  /* XXX lastplay, playtime, lastedit, etc. */
};

struct res_query : public one_result {
  virtual const res_query * is_query() const { return this; }

  string name;

  vector<string> tags;

  const lquery *query;
};

/* A queryresult consists of the result set and a function
   for incrementally updating it. */
struct queryresult {
  /* Snapshot of the uptodate call for leveldb. */
  bool complete;
  float pct_disk, pct_verify;

  vector<const one_result *> results;
};

/* there is just one global level database. */
struct leveldb {
  
  /* set the player once before adding source dirs/files
     or issuing queries. */
  static void setplayer(player *);
  static player * getplayer();

  /* set the sources that the database will use. */
  /* Add all files in this dir (n.b. not currently recursive) */
  static void addsourcedir(string);
  /* Add a specific file. */
  static void addsourcefile(string);

  /* Returns true if we've loaded everything we know about.
     If not, and the floats are non-NULL, set them to the
     estimated completion percentage for loading files from
     disk, and parsing and verifying the levels and solutions.
     pct_verify is always less than or equal to pct_disk. */
  static bool uptodate(float * pct_disk = 0, float * pct_verify = 0);

  /* The leveldb won't get up to date unless the caller donates time
     to it. Smaller maxima mean less progress but less latency. For
     ticks, we basically always go over (can't predict how long it
     will take to load from disk or even to verify a solution) by one
     quantum. */
  static void donate(int max_files, int max_verifies, int max_ticks);

  /* Returns a new-ly allocated result for the given lquery, which
     is owned by the caller. See leveldb-query.h to construct 
     lqueries. */
  static queryresult * query(const lquery &);

 private:
  leveldb();
};

#endif
