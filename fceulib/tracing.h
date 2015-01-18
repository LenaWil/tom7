#ifndef __TRACING_H
#define __TRACING_H

#include "trace.h"
#include "stringprintf.h"

// This file declares a global trace (if tracing is enabled) and macros
// for actually doing tracing within FCEUlib.

// Should normally be 0, unless debugging something. Traces are huge
// and slow everything down a lot!
#define TRACING 1

#if TRACING

extern Traces fceulib__traces;
#define TRACEF(...) fceulib__traces.TraceString(FCEU_StringPrintf( __VA_ARGS__ ))
#define TRACEV(v) fceulib__traces.TraceMemory(v)
#define TRACEA(p, s) fceulib__traces.TraceArray(p, s)
#define TRACEN(n) fceulib__traces.TraceNumber((uint64)n)
#define TRACE_ENABLE() fceulib__traces.Enable()
#define TRACE_DISABLE() fceulib__traces.Disable()
#define TRACE_SWITCH(s) fceulib__traces.SwitchTraceFile(s);

#else

#define TRACEF(...) do { } while (0)
#define TRACEV(v) do { } while (0)
#define TRACEA(p, s) do { } while (0)
#define TRACEN(n) do { } while (0)
#define TRACE_ENABLE() do { } while (0)
#define TRACE_DISABLE() do { } while (0)
#define TRACE_SWITCH(s) do { } while (0)

#endif  // TRACING

#endif
