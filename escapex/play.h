
#ifndef __PLAY_H
#define __PLAY_H

#include "level.h"
#include "player.h"
#include "dirt.h"
#include "draw.h"

/* XXX clean this up ! */

enum prtype {
  PR_QUIT, PR_ERROR, PR_SOLVED, PR_EXIT,
};

#define stat(fn, ty) \
  static playresult fn() { \
    playresult p; \
    p.type = PR_ ## ty; \
    return p; \
  }
 
/* XXX move ... */
struct playresult {
  
  prtype type;

  union u {
    solution * sol;
  } u;

  stat(quit, QUIT);
  stat(error, ERROR);

  static playresult solved(solution * s) {
    playresult p;
    p.type = PR_SOLVED;
    p.u.sol = s;
    return p;
  }

};

#undef stat

struct play : public drawable {
  static play * create ();
  virtual playresult doplay_save(player *, level *, solution *& saved, string md5) = 0;
  virtual playresult doplay(player * plr, level * lev, string md5) {
    solution * unused = 0;
    playresult res = doplay_save(plr, lev, unused, md5);
    unused->destroy();
    return res;
  }
  /* play, recording the game in the player's solution file */
  static void playrecord(string file, player * plr, bool allowrate = true);
  virtual void draw() = 0;
  virtual void screenresize() = 0;
  virtual void destroy () = 0;
  virtual ~play();

  /* makes move d (returning true if successful and false if not),
     animating the action.

     assumes a non-invalidated recent "draw()",
     caller should draw() after, too. */
  static bool animatemove(drawing & dr, disamb *&, dirt *&, dir d);
};

#endif
