
#ifndef __PROMPT_H
#define __PROMPT_H

#include "escapex.h"
#include "drawable.h"

struct prompt {
  
  string title;
  string input;
  string explanation;

  drawable * below;

  /* XXX should probably be just this static method,
     and perhaps in util */
  static string ask(drawable * b, string title, string def="");

  static prompt * create();

  string select();

  virtual ~prompt();

};

#endif
