
#ifndef __STARTUP_H
#define __STARTUP_H

struct startup {
  /* the name of the executable. used only for upgrade,
     so disabled for multiuser builds. */
# ifndef MULTIUSER
  static string self;
# endif
  
  /* change to the appropriate directory at startup.
     zero on error */

  static int setdir (int argc, char ** argv);

 private:

  static int install_levels(string);
};

#endif
