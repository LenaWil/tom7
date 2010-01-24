
#ifndef __REGISTRATION_H
#define __REGISTRATION_H
/* n.b., register is a keyword */

#include "escapex.h"
#include "player.h"

struct registration : public drawable {
  
  static registration * create (player * p);

  /* modifies p->webid to nonzero if successful */
  virtual void registrate() = 0;

  virtual ~registration() {}

  virtual void draw() = 0;
  virtual void screenresize() = 0;

  virtual void destroy() = 0;

};

#endif
