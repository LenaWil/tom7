#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <limits.h>
#include <math.h>

#include "driver.h"

#include "fceu.h"
#include "version.h"

#include "types.h"

/**
 * Prints an error string to STDOUT.
 */
void FCEUD_PrintError(char *s) {
  puts(s);
}

// Print error to stderr.
void FCEUD_PrintError(const char *errormsg) {
  fprintf(stderr, "%s\n", errormsg);
}

// morally FCEUD_
unsigned int *GetKeyboard() {
  abort();
}
