
#ifndef __RATING_H
#define __RATING_H

#include <string>
#include "drawable.h"

struct player;

/* some slack for later... */
#define RATINGBYTES 6

struct rating {
  
  string tostring();
  
  static rating * fromstring(string);

  static rating * create();

  void destroy();

  int difficulty;
  int style;
  int rigidity;
  /* should only be true if same player has solved */
  int cooked;

};


struct ratescreen : public drawable {
  
  static ratescreen * create (player * p, level * l, string levmd);

  /* pops up a menu to rate the level identified
     by md5 string levmd. It's rated by player p,
     and the level ptr is just used to display a
     thumbnail and some information.

     if the player is not registered, shows an error.

     if the player has already rated this level, this
     allows him to edit his old rating.
     
     this call manages the rating in the player's file,
     saving the file if necessary, and updating the
     rating on the internet.

     doesn't free player or level objects.
  */
  virtual void rate() = 0;

  virtual ~ratescreen() {}

  virtual void draw() = 0;
  virtual void screenresize() = 0;

  virtual void destroy() = 0;

  virtual void setmessage(string) = 0;

  drawable * below;

};


#endif

