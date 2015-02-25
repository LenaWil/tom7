
/*
    Derived from source copyright Kevlin Henney, 1997, 2003. 

    THIS FILE ONLY:

    Permission to use, copy, modify, and distribute this software and its
    documentation for any purpose is hereby granted without fee, provided
    that this copyright and permissions notice appear in all copies and
    derivatives.
    
    This software is supplied "as is" without express or implied warranty.

    But that said, if there are any problems please get in touch.

*/

#ifndef __DIRENT_H
#define __DIRENT_H

#ifndef _MSC_VER
/* posix */
#  include <sys/types.h>
#  include <dirent.h>
#  include <unistd.h>

#else

typedef struct DIR DIR;

struct dirent {
  char *d_name;
};

DIR           *opendir(const char *);
int           closedir(DIR *);
struct dirent *readdir(DIR *);
void          rewinddir(DIR *);

#endif /* win32 */

/* no good place to put this, since
   dirent.cc is not linked in unix */
inline int dirsize (const char * dir) {
  DIR * d = opendir(dir);
  if (!d) return 0;
  int i = 0;
  dirent * de;
  for(;;i++) {
    de = readdir(d);
    if (!de) break;
  }
  closedir(d);
  return i;
}


#endif
