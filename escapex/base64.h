
#ifndef __BASE64_H
#define __BASE64_H

#include <string>
using namespace std;

struct base64 {
  static string encode(string);
  /* XXX good if it could do error checking */
  static string decode(string);
};

#endif
