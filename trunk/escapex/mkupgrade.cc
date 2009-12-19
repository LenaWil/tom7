
#include <string>
#include <stdio.h>
#include "version.h"
#include "oldest.h"
#include "recommend.h"
// #include "util.h"
#include "md5.h"


#include <iostream>
#include <fstream>


/* generate the UPGRADE file for a platform. 
   see protocol.txt.
*/

#ifndef PLATFORM
#  ifdef WIN32
#    define PLATFORM "win32"
#  else 
#    ifdef OSX
#      define PLATFORM "osx"
#    else /* assume linux */
#      define PLATFORM "linux"
#    endif
#  endif
#endif

#define MAX_FILES 1024

enum entt { T_FILE, T_SYMLINK, T_DELETE, };
struct fentry {
  entt t;
  string filename;
  string dest; /* for symlinks */
};

int main (int argc, char ** argv) {

  md5::init();

  if (!strcmp(argv[1], "-mkbat")) {

    /* XXX unused now */
    for(int i = 3; i < argc; i ++) {
      printf("copy %s %s\n",
	     argv[i], argv[2]);
    }

  } else if (!strcmp(argv[1], "-v")) {
    
    printf("%s\n", VERSION);

  } else {

    /* now accept three parameters, indicating files.
       releasefiles.platform
       symlinks.platform
       deletefiles.platform 

       releasefiles and deletefiles are just lists of files (one per
       line), but symlinks have two files per line with

       nameofsymlink    destination
    */

    if (argc != 4) {
      fprintf(stderr, 
	      "usage:\n"
	      "mkupgrade.exe releasefiles.platform "
	      "symlinks.platform deletefiles.platform\n",
	      "(must supply a file for each, even if it's blank.)\n"
	      "writes to stdout.\n");
      exit(-1);

    } else {

      ifstream rel(argv[1]);
      ifstream sym(argv[2]);
      ifstream del(argv[3]);

      if (!(rel && sym && del)) {
	fprintf(stderr, "can't open files\n");
	exit(-1);
      }

      int n = 0;
      fentry * entries = new fentry[MAX_FILES];

      string f;
      while (rel >> f) {
	entries[n].t = T_FILE;
	entries[n].filename = f;
	n ++;
      }

      string d;
      while (sym >> f >> d) {
	entries[n].t = T_SYMLINK;
	entries[n].filename = f;
	entries[n].dest = d;
	n ++;
      }

      while (del >> f) {
	entries[n].t = T_DELETE;
	entries[n].filename = f;
	n ++;
      }

      /* now output. */

      /* number of files */
      printf ("%d\n", n);
      printf ("%s\n", OLDEST);
      printf ("%s\n", RECOMMEND);
      printf ("%s\n", VERSION);
      /* arbitrary date string -- could make nicer */
      printf ("%s %s\n", PLATFORM, VERSION);

      /* output entries. */
      for(int i = 0; i < n; i ++) {
	switch(entries[i].t) {
	case T_FILE: {
	  string fi = entries[i].filename;
	  FILE * ff = fopen(fi.c_str(), "rb");
	  if (!ff) {
	    fprintf(stderr, "Couldn't open %s\n", fi.c_str());
	    return -1;
	  }
	  string s = md5::ascii(md5::hashf(ff));
	  printf("%s u %s\n", fi.c_str(), s.c_str());
	  fclose(ff);
	  break;
	}
	case T_SYMLINK: {
	  printf("%s ? ->%s\n", 
		 entries[i].filename.c_str(),
		 entries[i].dest.c_str());
	  break;
	}
	case T_DELETE: {
	  printf("%s ? *\n",
		 entries[i].filename.c_str());
	  break;
	}
	default: fprintf(stderr, "?!?\n"); exit(-1);
	}
      }

    }
  }

  return 0;
}
