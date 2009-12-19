
/* this code updates the version in version.h.
   It's only necessary for building official releases,
   and it shouldn't be included in the escape executable. */

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string>
#include "version.h"

#define VERSION_H "version.h"

using namespace std;

static string itos(int i) {
  char s[64];
  sprintf(s, "%d", i);
  return (string)s;
}

int main (int argc, char ** argv) {

  char buf[256];

  const time_t t = time(0);

  strftime(buf, 255, "%Y%m%d0", localtime(&t));

  int n = atoi(buf);
  int oldn = atoi(VERSION);

  if (n / 10 <= oldn / 10) {
    n = oldn + 1;
    if (n / 10 != oldn / 10) {
      fprintf(stderr, "Warning: more than 10 versions today!\n");
    }
  }

  FILE * vh = fopen(VERSION_H, "w");
  
  if (!vh) { 
    printf ("Can't open " VERSION_H " \n");
    exit(-1);
  }

  fprintf(vh, "/* Generated file! Do not edit. */\n");
  fprintf(vh, "#define VERSION \"%d\"\n", n);

  /* need to write this before committing... */
  fclose(vh);

  string sys = (string)"cvs commit -m \"version " + itos(n) + (string)"\"";
  system(sys.c_str());
  string sys2 = (string)"cvs tag -c escape-" + itos(n);
  system(sys2.c_str());

  return 0;
}
