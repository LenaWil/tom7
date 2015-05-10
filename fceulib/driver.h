#ifndef __DRIVER_H_
#define __DRIVER_H_

#include <stdio.h>
#include <string>
#include <iosfwd>

#include "types.h"
#include "git.h"
#include "file.h"

FILE *FCEUD_UTF8fopen(const char *fn, const char *mode);
inline FILE *FCEUD_UTF8fopen(const std::string &n, const char *mode) { 
  return FCEUD_UTF8fopen(n.c_str(),mode); 
}

EMUFILE_FILE* FCEUD_UTF8_fstream(const char *n, const char *m);
inline EMUFILE_FILE* FCEUD_UTF8_fstream(const std::string &n, const char *m) {
  return FCEUD_UTF8_fstream(n.c_str(),m); 
}

void FCEU_printf(char *format, ...);

// Displays an error.  Can block or not.
void FCEUD_PrintError(const char *s);

#endif

