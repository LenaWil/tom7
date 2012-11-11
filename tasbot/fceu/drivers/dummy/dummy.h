#ifndef __FCEU_DUMMY_H
#define __FCEU_DUMMY_H

// #include <DUMMY.h>
#include "main.h"
// #include "dface.h"
// #include "input.h"

static void DoFun(int frameskip);
static int isloaded = 0;
extern int noGui;

int LoadGame(const char *path);
int CloseGame(void);

#endif
