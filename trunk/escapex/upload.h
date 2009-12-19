
#ifndef __UPLOAD_H
#define __UPLOAD_H

#include "escapex.h"
#include "player.h"

/* Upload a level and its solution to the server. */

enum upresult { UL_OK, UL_FAIL, };

struct upload : public drawable {
  static upload * create ();
  virtual ~upload();
  virtual void destroy () = 0;

  virtual upresult up(player * p, string file, string desc) = 0;

  virtual void draw() = 0;
  virtual void screenresize() = 0;
};



#endif
