// Logging package that supports concurrency (specifically, it prevents
// messages from overwriting one another). This requires initialization
// and concurrency.h, so libraries destined for cc-lib shouldn't depend
// on it. Note that base.h also defines CHECK and UNIMPLEMENTED and so
// on; this undefines those and then replaces them with concurrent
// versions.

#ifndef __LOGGING_H
#define __LOGGING_H

#include "concurrency.h"
#include "base.h"
#include <ostream>

struct Logging {
  static void Init();

  // It's not intended for these to be called except by the
  // macros below.
  static void GlobalLock();
  static void GlobalUnlock();

 private:
  ALL_STATIC(Logging);
};

int lprintf(const char *fmt, ...)
// TODO: Optional G++ extension; wrap it...
// Note gnu_printf on mingw tells it to use ANSI %lld etc.,
// instead of microsoft ones.
  __attribute__ ((format (gnu_printf, 1, 2)));

#undef UNIMPLEMENTED
#undef CHECK
#undef DCHECK

#define UNIMPLEMENTED(message) \
  do {							\
    Logging::GlobalLock();				\
    fflush(stderr);					\
    fprintf(stderr, "%s:%s:%d. Unimplemented: %s\n",	\
	__FILE__, __func__, __LINE__, #message);	\
    fflush(stderr);					\
    abort();						\
  } while (0)

// TODO: Make it possible to do CHECK(cond) << "helpful message";
// TODO: Push some of this into a function to avoid code bloat?
#define CHECK(condition)				    \
  do { if (!(condition)) {				    \
      /* XXX */						    \
      fprintf(stderr, "(aborting)\n");			    \
      Logging::GlobalLock();				    \
      fflush(stderr);					    \
      fprintf(stderr, "%s:%s:%d. Check failed: %s\n",	    \
	      __FILE__, __func__, __LINE__, #condition	    \
	      );					    \
      fflush(stderr);					    \
      abort();						    \
    } } while(0)

#if DEBUG
#  define DCHECK(condition) CHECK(condition)
#else
#  define DCHECK(condition) do { } while(0)
#endif


#endif
