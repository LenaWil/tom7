
#ifndef __BROWSE_H
#define __BROWSE_H

/* New (4.0) version of level browser. Implements the UI on top of
   leveldb.

   Since it's based on leveldb, it can only be used for that global
   player (this is natural, anyway, because you only want to browse
   from the perspective of the logged-in player).
 */

#include "escapex.h"
#include "font.h"
#include "selector.h"
#include "player.h"
#include "util.h"

/* abstract interface */
struct browse : public drawable {

  static browse * create(bool allow_corrupted = false);
  virtual ~browse() {}
  virtual void destroy() = 0;

  /* Display the browser modally until the user selects a level;
     return a filename for that level or the empty string if
     the user cancels. */
  virtual string selectlevel() = 0;

  /* drawable */
  virtual void draw () = 0;
  virtual void screenresize () = 0;
};

#endif
