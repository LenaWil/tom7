
#include "escapex.h"
#include "util.h"
#include "cleanup.h"

#include <sys/stat.h>
#include "dirent.h"
#include "edit.h"
#include "dircache.h"

void cleanup::clean() {
  
  DIR * d = opendir(".");
  if (!d) return;
  dirent * dire;

  while( (dire = readdir(d)) ) {

    string dn = dire->d_name;
    string ldn = "." + (string)DIRSEP + dn;

    if (util::isdir(ldn)) {
      /* XXX could be recursive?? */

    } else {

      if (util::endswith(dn, ".deleteme")) {
	/* printf(" remove '%s'\n", ldn.c_str()); */
	util::remove(ldn);
      }
    }
  }

  /* harmless if it fails, unless there is a *file*
     called mylevels, in which case we are screwed... */
  util::makedir(EDIT_DIR);

  /* make attic dir. Make sure it is ignored. */
  util::makedir(ATTIC_DIR);
  writefile((string)ATTIC_DIR + DIRSEP + IGNOREFILE, "");

  closedir(d);


}
