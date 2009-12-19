
#ifndef __HANDHOLD_H
#define __HANDHOLD_H

#include "level.h"
#include "sdlutil.h"

#include "util.h"
#include "escapex.h"
#include "font.h"

struct handhold {
  
  /* do something the first time the game is launched */
  static void firsttime ();
  static void init ();

  static void did_update ();
  static void did_upgrade ();

  static bool recommend_update();
  static bool recommend_upgrade();

};


#endif
