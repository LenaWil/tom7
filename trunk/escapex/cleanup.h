
#ifndef __CLEANUP_H
#define __CLEANUP_H

/* looks through the current directory
   for any files named *.deleteme,
   and deletes them. also ensures that
   some expected game dirs actually exist,
   such as 'mylevels'*/
struct cleanup {
  static void clean ();
};

#endif
