#ifndef __CHECKFILE_H
#define __CHECKFILE_H

#include "escapex.h"
#include "util.h"

/* nicer interface to files. automatically closes
   on destroy, automatically checks eof. */

/* XXX also check eof when these functions are called */

struct checkfile {
  FILE * ff;
  bool read(unsigned int bytes, string & s) {
    /* fread stupidly *fails* if the size is 0 */
    if (bytes == 0) return "";
    char * r = new char[bytes];
    string ss(bytes, '*');
    if (fread(r, bytes, 1, ff) == 1) {
      for(unsigned int i = 0; i < bytes; i ++) ss[i] = r[i];
      s = ss;
      delete [] r;
      return 1;
    } else {
      delete [] r;
      return 0;
    }
  }
  
  void destroy() { fclose(ff); delete this; }

  static checkfile * create(string f) {
    checkfile * cf = new checkfile();
    cf->ff = fopen(f.c_str(), "rb");
    if (cf->ff) return cf;
    else { delete cf; return 0; }
  }

  bool readint(int & i) {
    string s;
    if (!read(4, s)) return 0;
    i = 
      ((unsigned char)s[0] << 24) |
      ((unsigned char)s[1] << 16) |
      ((unsigned char)s[2] << 8) |
      ((unsigned char)s[3]);
    return 1;
  }

  bool getline(string & s) {
    if (feof(ff)) return false;
    s = util::fgetline(ff);
    return true;
  }
};

#endif
