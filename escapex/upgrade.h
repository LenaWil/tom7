
#ifndef __UPGRADE_H
#define __UPGRADE_H

#include "escapex.h"
#include "player.h"
#include "http.h"
#include "draw.h"

/* should be in a config somewhere */
#define UPGRADEURL "/" PLATFORM "/UPGRADE"

/* XXX no real difference between UP_FAIL and UP_OK. */
enum upgraderesult {
  UP_FAIL, UP_OK, UP_EXIT,
};

/* upgrading is updating Escape itself. */
struct upgrader : public drawable {
  static upgrader * create(player * p);
  virtual upgraderesult upgrade(string & msg) = 0;
  virtual void destroy () = 0;
  virtual ~upgrader() {};

  virtual void draw() = 0;
  virtual void screenresize() = 0;
};

#endif
