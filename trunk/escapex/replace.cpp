
/* upgrade trampoline for windows only
   does a series of moves (on the command line as
   execafter.exe    src dst   src dst   src dst)
   
   then execs: 
     execafter.exe -upgraded


   Replace waits a few seconds and tries again on
   failure, in order to avoid race conditions.
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <time.h>

#include <windows.h>
#include <malloc.h>

#include "util.h"

#ifdef WIN32
/* execl */
#  include <process.h>
#  define sleep _sleep
#endif

#ifndef WIN32
# error "replace.cpp is only for win32 builds!"
#endif


int main(int argc, char ** argv) {

# if 0
  printf("this is replace.exe\n\n");
  fflush(stdout);

  for(int aa = 0; aa < argc; aa++) {
    printf("argv[%d] = '%s'\n", aa, argv[aa]);
  }
# endif

  if (argc >= 2) {

    string execafter = argv[1];

    /* ignores odd argument */
    for(int i = 2; i < (argc - 1); ) {
      int tries = 3;
      
      while (tries--) {
	if ((util::remove(argv[i + 1]) &&
	     util::move(argv[i], argv[i+1]))) goto success;
	
	sleep(1);
      }

      {
	char msg[512];
	_snprintf(msg, 500, "failed to remove %s or move %s to %s", 
		  argv[i + 1], argv[i], argv[i + 1]);
	MessageBox(0, msg, "upgrade problem?", 0);
      }
      
    success:
      i += 2;
    }

    for(int tries = 0; tries < 3; tries ++) {

      spawnl(_P_OVERLAY, execafter.c_str(), execafter.c_str(),
	     "-upgraded", 0);

      /* ok: win32 only */
      sleep(1 << tries);
    }
      
    MessageBox(0, "Exec failed\n", "upgrade incomplete", 0);
    return -2;

  } else {
    MessageBox(0, 
	       "replace.exe is used during the upgrade process and isn't\n"
	       "very interesting to just run by itself.\n\n", "oops",
	       0);
    return -1;
  }
}
