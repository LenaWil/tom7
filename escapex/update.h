
#ifndef __UPDATE_H
#define __UPDATE_H

#include "escapex.h"
#include "level.h"
#include "player.h"
#include "http.h"
#include "draw.h"

/* should be in a config somewhere */
#define COLLECTIONSURL "/COLLECTIONS"

enum updateresult {
  UD_SUCCESS, UD_FAIL,
};

/* update */
struct updater : public drawable {
  static updater * create(player * p);
  virtual updateresult update(string & msg) = 0;
  virtual void destroy () = 0;
  virtual ~updater() {};

  virtual void draw() = 0;
  virtual void screenresize() = 0;
};

#endif
