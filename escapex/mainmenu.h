
#ifndef __MAINMENU_H
#define __MAINMENU_H

#include "escapex.h"
#include "player.h"
#include "mainshow.h"

struct mainmenu {

  enum result { LOAD, QUIT, EDIT, REGISTER, UPDATE, UPGRADE, LOAD_NEW, };

  virtual result show () = 0;

  static mainmenu * create(player * plr);

  virtual void destroy() = 0;
  virtual ~mainmenu() {}
  
};


#endif
