
#include "level.h"
#include "util.h"

#include <string>

string changeext(string in) {
  int i = (signed)in.length() - 1;
  for(; i >= 0; i--) {
    if (in[i] == '.') break;
  }

  if (i < 0) return in + ".esx";
  else return in.substr(0, i) + ".esx";
}

/* this command-line interface won't be very useful
   on windows, because stdout is sent to a file... */
int main (int argc, char ** argv) {

  if (argc == 3 || argc == 2) {
    
    string in = argv[1];
    string ou = (argc == 3) ? argv[2] : changeext(util::lcase(argv[1]));

    string ins = readfile(in);

    if (ins == "") {
      printf("Can't open %s\n", in.c_str());
      return -1;
    }

    level * lev = level::fromoldstring(ins);

    if (!lev) {
      printf("Bad oldesc: %s\n", in.c_str());
      return -1;
    }

    string os = lev->tostring();

    if (os == "") {
      printf("Unable to make string??\n");
      return -1;
    }

    if (!writefile(ou, os)) {
      printf("Problem writing to %s\n", ou.c_str());
      return -1;
    }

    return 0;

  } else {
    printf("usage: ./convert in.esc [out.esx]\n");
    printf("Converts an Escape 1.0 level to an Escapex level.\n\n");

    return -1;
  }

  return 0;
}
