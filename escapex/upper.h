
#ifndef __UPPER_H
#define __UPPER_H

#include "escapex.h"
#include "level.h"
#include "player.h"
#include "http.h"
#include "textscroll.h"
#include "drawable.h"
#include "dirindex.h"

struct upper {
  virtual void destroy () = 0;
  virtual ~upper() {};

  /* create an upper, using the http connection hh,
     and directory dir */
  static upper * create(http * hh, textscroll * t,
			drawable * below, string dir);

  /* the file 'f' (which may be prefixed by directories that have been
     previously saved), should be set to the contents specified by the
     md5 hash md.

     returns true if we will be able to accomplish this. */
  virtual bool setfile(string f, string md, ratestatus votes,
		       int date, int speedrecord, int owner) = 0;

  /* creates the directory d (if it does not exist), and ensures that
     it will not be pruned. The index string becomes the directory's
     index.

     ""
     sub
     sub/dir/this

     invalid:

     /
     subdir/        */
  virtual void savedir(string d, string index) = 0;

  /* return true if committing is successful. if false, then the files
     in the directory may be damaged (moved to attic) but we try to do
     this as little as possible. */
  virtual bool commit() = 0;

};

/* The upper object is used to replace one set of files with another
   during the upgrade process.

   When created, it loads each of the files in the directory into
   memory, generating their MD5 hashes. This applies to subdirectories
   as well. So, there is a hashtable mapping md5s to file contents.
   ("content") There is also a hashtable mapping file names to
   oldentries.

   First, makedir is called on all of the subdirectories (and their
   index names) that need to exist. 

   Then, setfile is called on all of the filenames (and hashes of
   their contents) that are supposed to be in the collection. Each
   filename should exist only in subdirectories created by makedir
   above (or else be in the "root").
   
   If the md5 is not in the hashtable, then we download it using
   the http object (see protocol.txt). If this fails, then the entire
   process fails and setfile returns false.

   Then, the filename/md5 is added to a list, the newlist.

   For each oldentry, we have a flag 'delme' that is initially set to
   1. If we setfile to that file name, then we don't want to delete
   the file in the cleanup phase, so we set the deleteme flag to 0.
   
   Finally, when the client calls commit(), we:

    - look up the md5 for each item in the newlist, and write it
      over the file f. (the md5 is guaranteed to appear in our
      content hashtable) This may require creating subdirectories
      that lead up to that file.

    - delete all oldentries that have delme = 1
      (index files are removed; anything else is moved to the "attic")

    - write index files to any directory that had "savedir" called
      on it.

    - remove any empty directories.

*/

#endif
