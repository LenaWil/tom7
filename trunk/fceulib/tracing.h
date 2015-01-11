#ifndef __TRACING_H
#define __TRACING_H

#include "trace.h"

// This file declares a global trace (if tracing is enabled) and macros
// for actually doing tracing within FCEUlib.

// Should normally be 0, unless debugging something. Traces are huge
// and slow everything down a lot!
#define TRACING 1

#if TRACING
#include "stringprintf.h"

extern Traces fceulib__traces;
#define TRACEF(...) fceulib__traces.TraceString(StringPrintf( __VA_ARGS__ ))
#define TRACEV(v) fceulib__traces.TraceMemory(v)

#else

#define TRACEF(...) do { } while(0)
#define TRACEV(v) do { } while(0)

#endif  // TRACING

#endif
