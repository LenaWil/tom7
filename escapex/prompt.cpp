
#include "prompt.h"
#include "font.h"
#include "sdlutil.h"
#include "draw.h"
#include "chars.h"
#include "extent.h"
#include "menu.h"

/* XXX implement in terms of menu class?
   textinput is meant to be the same */

prompt * prompt::create() {
  prompt * pp = new prompt();
  pp->below = 0;
  return pp;
}

prompt::~prompt() {}

string prompt::ask(drawable * b, string t, string d) {
  prompt * pp = prompt::create();
  extentd<prompt> ep(pp);
  pp->title = t;
  pp->below = b;
  pp->input = d;

  return pp->select();
}

string prompt::select() {

  textinput inp;
  inp.question = title;
  inp.input = input;
  inp.explanation = explanation;

  vspace spacer((int)(fon->height * 1.5f));

  okay ok;
  ok.text = "Accept";

  cancel can;
  can.text = "Cancel";

  ptrlist<menuitem> * l = 0;

  ptrlist<menuitem>::push(l, &can);
  ptrlist<menuitem>::push(l, &ok);
  ptrlist<menuitem>::push(l, &spacer);
  ptrlist<menuitem>::push(l, &inp);
  // ptrlist<menuitem>::push(l, &lab);

  menu * mm = menu::create(below, GREY "Input Required", l, false);
  resultkind res = mm->menuize();
  ptrlist<menuitem>::diminish(l);
  mm->destroy ();
  
  if (res == MR_OK) {
    return inp.input;
  } else return ""; /* ?? */
}
