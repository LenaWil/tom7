#ifndef __TRACING_H
#define __TRACING_H

#include "trace.h"
#include "stringprintf.h"

// This file declares a global trace (if tracing is enabled) and macros
// for actually doing tracing within FCEUlib.

// Should normally be 0, unless debugging something. Traces are huge
// and slow everything down a lot!
#define TRACING 0

#if TRACING

// This one doesn't go into the FC object and can only be used
// single-threaded.
extern Traces fceulib__traces;
// Avoid calling StringPrintf if we're discarding the arg; this allows us
// to have TRACEF deep in the emulator inner loops, but enable it only
// for the specific iteration of interest, without big performance overhead.
#define TRACEF(...) if (!fceulib__traces.IsEnabled()) {} else fceulib__traces.TraceString(FCEU_StringPrintf( __VA_ARGS__ ))
#define TRACEV(v) if (!fceulib__traces.IsEnabled()) {} else fceulib__traces.TraceMemory(v)
#define TRACEA(p, s) if (!fceulib__traces.IsEnabled()) {} else fceulib__traces.TraceArray(p, s)
#define TRACEN(n) if (!fceulib__traces.IsEnabled()) {} else fceulib__traces.TraceNumber((uint64)n)
#define TRACEFUN() if (!fceulib__traces.IsEnabled()) {} else fceulib__traces.TraceString(__func__)
// When the files have changed a lot, TRACELOC should not use __LINE__.
#define TRACELOC() if (!fceulib__traces.IsEnabled()) {} else fceulib__traces.TraceString(FCEU_StringPrintf(__FILE__ ":%s:%d", __func__, 0 /* __LINE__ */))

#define TRACE_ENABLE() fceulib__traces.SetEnabled(true)
#define TRACE_DISABLE() fceulib__traces.SetEnabled(false)
#define TRACE_SWITCH(s) fceulib__traces.SwitchTraceFile(s);

// Note that this creates a decl, so it should not be used as a single
// statement. After all, the whole point is to denote the scope of the
// auto variable.
#define TRACE_SCOPED_ENABLE_IF(cond)				\
  struct FceuScopedTrace {					\
    FceuScopedTrace() : old(fceulib__traces.IsEnabled()) { }	\
    ~FceuScopedTrace() { fceulib__traces.SetEnabled(old); }	\
  private: bool old; } fceu_scoped_trace_instance;              \
  fceulib__traces.SetEnabled((cond))      

#define TRACECALL()							\
  struct FceuScopedTraceCall {						\
    FceuScopedTraceCall(const char *f) : f(f) { TRACEF("%s called", f); } \
    ~FceuScopedTraceCall() { TRACEF("%s finished", f); }		\
    private: const char *f; } fceu_scoped_trace_call(__func__)

#else

#define TRACEF(...) do { } while (0)
#define TRACEV(v) do { } while (0)
#define TRACEA(p, s) do { } while (0)
#define TRACEN(n) do { } while (0)
#define TRACEFUN() do { } while (0)
#define TRACELOC() do { } while (0)
#define TRACE_ENABLE() do { } while (0)
#define TRACE_DISABLE() do { } while (0)
#define TRACE_SWITCH(s) do { } while (0)
#define TRACE_SCOPED_ENABLE_IF(cond) struct S { } fceu_scoped_trace_instance; \
  (void)fceu_scoped_trace_instance;				   	      \
  do { } while (0)

#define TRACECALL() struct SC { } fceu_scoped_trace_call; (void)fceu_scoped_trace_call

#endif  // TRACING

// Derived forms
#define TRACE_SCOPED_STAY_ENABLED_IF(cond) \
  TRACE_SCOPED_ENABLE_IF(fceulib__traces.IsEnabled() && (cond))

#endif
