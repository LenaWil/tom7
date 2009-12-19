
#ifndef __COMMENTING_H
#define __COMMENTING_H

#include "escapex.h"

struct commentscreen {
  
  static void comment(player * plr, level * l, string md5,
		      bool cookmode = false);

};

#endif
