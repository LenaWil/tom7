
#ifndef __MD5_H
#define __MD5_H

#include <stdio.h>
#include <string>
using namespace std;

/* hashes are returned as 16-byte
   binary data strings. */
struct md5 {
  /* initialize MD5. This detects
     byte order and swaps if necessary */
  static void init ();

  static string hash(string);
  /* hashes the remainder of the file */
  static string hashf(FILE *);
  /* converts the input string into lowercase hex ascii */
  static string ascii(string);

  /* convert from mixed-case ascii to md5.
     true on success */
  static bool unascii(string, string & out);
};

#endif
