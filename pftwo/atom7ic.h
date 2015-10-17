#ifndef __ATOM7IC_H
#define __ATOM7IC_H


#include <atomic>

static_assert(ATOMIC_INT_LOCK_FREE == 2,
	      "Integers aren't atomic. :-(");

static_assert(ATOMIC_POINTER_LOCK_FREE == 2,
	      "Pointers aren't atomic. :-(");

#endif
