#ifndef __DRIVER_H_
#define __DRIVER_H_

#include <stdio.h>
#include <string>
#include <iosfwd>

#include "types.h"
#include "git.h"
#include "file.h"

void FCEU_printf(char *format, ...);

// Displays an error.  Can block or not.
void FCEUD_PrintError(const char *s);

#endif

