#ifndef _DEBUG_H_
#define _DEBUG_H_

#include "git.h"
#include "types.h"

extern int GetPRGAddress(int A);

static constexpr bool debug_loggingCD = false;

//--------debugger
void DebugCycle();
//-------------

#endif
