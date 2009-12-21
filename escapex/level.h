
#ifndef __LEVEL_H
#define __LEVEL_H

#include <string>
#include <cstring>
#include <string.h>

using namespace std;

#define LEVELMAGIC "ESXL"

#define LEVEL_MAX_HEIGHT 100
#define LEVEL_MAX_WIDTH  100
#define LEVEL_MAX_AREA   2048
#define LEVEL_MAX_ROBOTS 15
#define LEVEL_BOMB_MAX_TIMER   10

typedef int dir;

enum {
  DIR_NONE, DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT,
};

#define FIRST_DIR_SELF DIR_NONE
#define FIRST_DIR DIR_UP
#define LAST_DIR DIR_RIGHT

inline dir turnleft(dir d) {
  switch(d) {
  case DIR_UP: return DIR_LEFT;
  case DIR_DOWN: return DIR_RIGHT;
  case DIR_RIGHT: return DIR_UP;
  case DIR_LEFT: return DIR_DOWN;
  default:
  case DIR_NONE: return DIR_NONE; /* ? */
  }
}

inline dir turnright(dir d) {
  switch(d) {
  case DIR_UP: return DIR_RIGHT;
  case DIR_DOWN: return DIR_LEFT;
  case DIR_RIGHT: return DIR_DOWN;
  case DIR_LEFT: return DIR_UP;
  default:
  case DIR_NONE: return DIR_NONE; /* ? */
  }
}

inline void dirchange(dir d, int & dx, int & dy) {
  switch(d) {
  case DIR_UP:
    dx = 0;
    dy = -1;
    break;
  case DIR_LEFT:
    dx = -1;
    dy = 0;
    break;
  case DIR_RIGHT:
    dx = 1;
    dy = 0;
    break;
  case DIR_DOWN:
    dx = 0;
    dy = 1;
    break;
  }
}

inline string dirstring(dir d) {
  switch(d) {
  case DIR_UP: return "up";
  case DIR_LEFT: return "left";
  case DIR_RIGHT: return "right";
  case DIR_DOWN: return "down";
  case DIR_NONE: return "none";
  default:
    return "??";
  }
}

inline dir dir_reverse(dir d) {
  switch(d) {
  case DIR_UP: return DIR_DOWN;
  case DIR_LEFT: return DIR_RIGHT;
  case DIR_DOWN: return DIR_UP;
  case DIR_RIGHT: return DIR_LEFT;
  default:
  case DIR_NONE: return DIR_NONE;    
  }
}

/* panel colors */
enum {
  PANEL_REGULAR = 0,
  PANEL_BLUE = 1,
  PANEL_GREEN = 2,
  PANEL_RED = 3,
};

enum tflag {
  TF_NONE = 0, 

  /* panel under tile (ie, pushable block) */
  /* if HASPANEL is set,
     then TF_RPANELH * 2 + TF_RPANELL
     says what kind (see panel colors above) */
  TF_HASPANEL = 1, 

  TF_RPANELL = 4,
  TF_RPANELH = 8,

  /* panel under tile in bizarro world */
  /* same refinement */
  TF_OPANEL = 2,

  TF_ROPANELL = 16,
  TF_ROPANELH = 32,

  /* reserved for various purposes during
     move */
  TF_TEMP = 64,
};

enum tile {
  T_FLOOR, T_RED, T_BLUE, T_GREY, T_GREEN, T_EXIT, T_HOLE, T_GOLD, 
  T_LASER, T_PANEL, T_STOP, T_RIGHT, T_LEFT, T_UP, T_DOWN, T_ROUGH,
  T_ELECTRIC, T_ON, T_OFF, T_TRANSPORT, T_BROKEN, T_LR, T_UD, T_0,
  T_1, T_NS, T_NE, T_NW, T_SE, T_SW, T_WE, T_BUTTON, T_BLIGHT, 
  T_RLIGHT, T_GLIGHT, T_BLACK, T_BUP, T_BDOWN,
  T_RUP, T_RDOWN, T_GUP, T_GDOWN, 
  T_BSPHERE, T_RSPHERE, T_GSPHERE, T_SPHERE,
  T_TRAP2, T_TRAP1,
  
  T_BPANEL, T_RPANEL, T_GPANEL,
  
  T_STEEL, T_BSTEEL, T_RSTEEL, T_GSTEEL, 

  T_HEARTFRAMER, T_SLEEPINGDOOR, 

  T_TRANSPONDER, T_NSWE, T_REMOTE,

  /*
  T_DIRRIGHT, T_DIRUP, T_DIRDOWN, T_DIRLEFT,
  */

  NUM_TILES,
};

enum bot {
  B_BROKEN,
  B_DALEK,
  B_HUGBOT,

  /* no sleeping broken, since it would be
     identical to regular broken. */
  B_DALEK_ASLEEP,
  B_HUGBOT_ASLEEP,

  /* BOMB_n is a bomb with max timer n. 
     the bot data indicates the current
     timer value. */
  /* explodes immediately after being pushed */
  B_BOMB_0,
  /* ... not named ... */
  B_BOMB_MAX = B_BOMB_0 + LEVEL_BOMB_MAX_TIMER,

  NUM_ROBOTS,

  /* can't place on map, but is used to identify
     the type of an entity in general */
  B_PLAYER = -1,
  /* deleted bots arise from destruction. They
     are invisible and inert. We can't rearrange
     the bot list because their indices are used
     in an essential way as identities. */
  B_DELETED = -2,

  /* exploded bomb; becomes deleted next turn */
  B_BOMB_X = -3,

};

/* optional, since the Escape server wants to be able to
   validate solutions without knowing anything about
   animation. */
#ifndef NOANIMATION
# include "util.h"
# include "aevent.h"
#endif


/* a solution is just a list of moves */
struct solution {
  int length;
  int allocated;

  /* true if verified in this run of the program. 
     XXX this is a little awkward, since we don't
     have the level that this is purportedly a
     solution for handy. perhaps this should be in
     the playerdb instead. */
  bool verified;
  
  dir * dirs;

  string tostring();

  static solution * fromstring(string s);

  solution * clone() {
    solution * s = new solution();
    s->length = length;
    s->allocated = allocated;
    s->dirs = (dir*) malloc(allocated * sizeof (dir));
    s->verified = verified;
    /* PERF memcpy */
    for(int i = 0; i < length; i ++) {
      s->dirs[i] = dirs[i];
    }
    return s;
  }

  void destroy() {
    free(dirs);
    delete this;
  }

  static solution * empty() {
    solution * s = new solution();
    s->length = 0;
    s->allocated = 32;
    s->dirs = (dir*) malloc(32 * sizeof (dir));
    s->verified = false;
    return s;
  }

  void clear() {
    length = 0;
  }

  void append(dir d) {
    if (length == allocated) {
      dir * tmp = dirs;
      allocated <<= 1;
      dirs = (dir*) malloc(allocated * sizeof (dir));
      memcpy(dirs, tmp, length * sizeof (dir));
      free(tmp);
    }
    dirs[length++] = d;
    verified = false;
  }

  struct iter {
    int pos;
    solution * sol;
  
    iter(solution * s) : pos(0), sol(s) {}
    bool hasnext() { return pos < sol->length; }
    void next() { pos ++; }
    dir item () { return sol->dirs[pos]; }

  };

  void appends(solution * s) {
    for (iter i(s); i.hasnext(); i.next()) {
      append(i.item());
    }
  }


};

#ifndef NOANIMATION
/* disambiguation context.
   used only within animation; keeps track
   of where action has occurred on the
   grid -- if two actions interfere, then
   we serialize them. 
   
   Disambiguation contexts are associated with
   a particular level and shan't be mixed up!
*/
struct disamb {
  /* array of serial numbers. */
  int w, h;
  unsigned int * map;
  
  /* last serial in which the player was updated */
  unsigned int player;
  /* same, bots */
  unsigned int bots[LEVEL_MAX_ROBOTS];

  /* keep track of current serial */
  unsigned int serial;

  static disamb * create(struct level *);
  void destroy();

  /* sets everything to serial 0 */
  void clear();

  /* affect a location. This might
     cause the serial to increase. Call this
     before creating the associated animation. Returns true if
     the serial did increase. */
  bool affect(int x, int y, level * l, ptrlist<aevent> **& etail);
  bool affecti(int idx, level * l, ptrlist<aevent> **& etail);

  /* should be paired with calls to 'affect' 
     for the squares that these things live in */
  void preaffectplayer(level * l, ptrlist<aevent> **& etail);
  void preaffectbot(int i, level * l, ptrlist<aevent> **& etail);

  void postaffectplayer();
  void postaffectbot(int i);
  

  void serialup(level * l, ptrlist<aevent> **& etail);

  // For debugging
  int serialat(int x, int y) { return map[y * w + x]; }
};
#endif


struct level {
  
  string title;
  string author;

  int w;
  int h;

  int guyx;
  int guyy;
  dir guyd;

  /* robots */
  int nbots;
  /* locations (as indices) */
  int * boti;
  /* bot type */
  bot * bott;
  /* not saved with file; just presentational. putting the player
     direction in drawing just barely works; it should probably
     be here, too. */
  dir * botd;
  /* not presentational, but also not saved with the file;
     intialized to -1 on load. (e.g., current bomb timers) */
  int * bota;

  /* shown */
  int * tiles;
  /* "other" (tiles swapped into bizarro world by panels) */
  int * otiles;
  /* destinations for transporters and panels (as index into tiles) */
  int * dests;
  /* has a panel (under a pushable block)? etc. */
  int * flags;

  /* true if corrupted on load. never saved */
  bool corrupted;

  bool iscorrupted() {
    return corrupted;
  }

  /* go straight to the target. no animation */
  void warp(int & entx, int & enty, int targx, int targy) {
    int target = tileat(targx, targy);

    checkstepoff(entx, enty);
    /* XXX can be incorrect --
       need to use SETENTPOS, since we need to reflect
       this immediately in the boti array 
       (so that serialup knows where the bot is standing) */
    entx = targx;
    enty = targy;

    switch(target) {
    case T_PANEL:
      swapo(destat(targx,targy));
      break;
    default:;
    }
  }

  void where(int idx, int & x, int & y) {
    x = idx % w;
    y = idx / w;
  }

  int index(int x, int y) {
    return (y * w) + x;
  }

  int tileat(int x, int y) {
    return tiles[y * w + x];
  }

  int otileat(int x, int y) {
    return otiles[y * w + x];
  }

  void settile(int x, int y, int t) {
    tiles[y * w + x] = t;
  }

  void osettile(int x, int y, int t) {
    otiles[y * w + x] = t;
  }

  void setdest(int x, int y, int xd, int yd) {
    dests[y * w + x] = yd * w + xd;
  }

  int destat(int x, int y) {
    return dests[y * w + x];
  }


  void getdest(int x, int y, int & xd, int & yd) {
    xd = dests[y * w + x] % w;
    yd = dests[y * w + x] / w;
  }

  void swapo(int idx);

  int flagat(int x, int y) {
    return flags[y * w + x];
  }

  void setflag(int x, int y, int f) {
    flags[y * w + x] = f;
  }

  bool iswon() {
    return tileat(guyx, guyy) == T_EXIT;
  }

  bool travel(int x, int y, dir d, int & nx, int & ny) {
    switch(d) {
      /* sometimes useful, for instance looping over all 
	 affected tiles when bombing */
    case DIR_NONE:
      nx = x;
      ny = y;
      return true;
    case DIR_UP:
      if (y == 0) return false;
      nx = x;
      ny = y - 1;
      break;
    case DIR_DOWN:
      if (y == (h - 1)) return false;
      nx = x;
      ny = y + 1;
      break;
    case DIR_LEFT:
      if (x == 0) return false;
      nx = x - 1;
      ny = y;
      break;
    case DIR_RIGHT:
      if (x == (w - 1)) return false;
      nx = x + 1;
      ny = y;
      break;
    default: return false; /* ?? */
    }
    return true;
  }

  /* shot by laser at (tilex, tiley) in direction (dir),
     or standing on a non-deleted bot. */
  bool isdead(int & tilex, int & tiley, dir & d);

  /* returns true if move had effect. */
  bool move(dir);
  /* pass the entity index, or -1 for the player */
  bool moveent(dir, int enti, unsigned int, int, int);

# ifndef NOANIMATION
  /* see animation.h for documentation */
  bool move_animate(dir, disamb * ctx, ptrlist<aevent> *& events);
  bool moveent_animate(dir, int enti, unsigned int, int, int, 
		       ptrlist<aevent> *&,
                       disamb * ctx, ptrlist<aevent> **&);
  void bombsplode_animate(int now,
			  int bombi, disamb * ctx, ptrlist<aevent> *& events,
			  ptrlist<aevent> **& etail);
# endif

  void bombsplode(int now, int bombi);

  /* create clone of current state. */
  level * clone();

  /* writes current state into a string */
  string tostring();

  /* 0 on error. if allow_corrupted is true, it returns a
     valid level with as much data from the original as
     possible (but may still return 0) */
  static level * fromstring(string s, bool allow_corrupted = false);
  
  /* 0 on error */
  static level * fromoldstring(string s);

  static level * blank(int w, int h);
  static level * defboard(int w, int h);

  /* correct a level (bad tiles, bad destinations). returns
     true if the level was already sane. */
  bool sanitize();

  void destroy ();

  /* play to see if it wins, does not modify level or sol */
  static bool verify(level * lev, solution * s);
  /* returns a simplified solution, if s solves lev somewhere
     along the way. if the return is false, then out is garbage */
  static bool verify_prefix(level * lev, solution * s, solution *& out);

  /* execute solution. returns early (# moves set in moves)
     if we die (return false) or win (return true). false upon
     completing without winning or dying. */
  bool play(solution *, int & moves);
  /* only 'length' moves of the solution, starting from move 'start' */
  bool play_subsol(solution *, int & moves, int start, int length);

  static int * rledecode(string s, unsigned int & idx, int n);
  static string rleencode(int n, int * a);

  void resize(int neww, int newh);

  static bool issphere(int t);
  static bool issteel(int t);
  static bool ispanel(int t);
  static bool triggers(int tile, int panel);
  static bool allowbeam(int tile);

  /* return the lowest index bot at a specific location
     (if there's one there). We count B_DELETED and B_BOMB_X
     as not bots. */
  bool botat(int x, int y, int & i) {
    int z = index(x, y);
    for(int m = 0; m < nbots; m ++) {
      if (boti[m] == z &&
	  bott[m] != B_DELETED && 
	  bott[m] != B_BOMB_X) {
	i = m;
	return true;
      }
    }
    return false;
  }

  bool isconnected(int x, int y, dir d);

  bool botat(int x, int y) {
    int dummy;
    return botat(x, y, dummy);
  }

  bool playerat(int x, int y) {
    return ((x == guyx) && (y == guyy));
  }

  static bool isbomb(bot b) {
    return ((int)b >= (int)B_BOMB_0 &&
	    (int)b <= (int)B_BOMB_MAX);
  }

  /* pre: b is bomb */
  static int bombmaxfuse(bot b) {
    return ((int)b - (int)B_BOMB_0);
  }

  static bool ispanel(int t, int & ref) {
    if (t == T_PANEL) { ref = PANEL_REGULAR; return true; }
    if (t == T_BPANEL) { ref = PANEL_BLUE; return true; }
    if (t == T_GPANEL) { ref = PANEL_GREEN; return true; }
    if (t == T_RPANEL) { ref = PANEL_RED; return true; }
    return false;
  }

  static bool needsdest(int t) {
    int dummy;
    return (t == T_REMOTE || t == T_TRANSPORT || ispanel(t, dummy));
  }

  private:
  /* solution wants access to rleencoding and decoding */
  friend struct solution;

  void checkstepoff(int, int);
  void checkleavepanel(int, int);
  static int newtile(int old);
  void swaptiles(int t1, int t2);
  void clearflag(int fl) {
    for(int i = 0; i < w * h; i++) {
      flags[i] &= ~fl;
    }
  }

  /* is the tile bombable? */
  static bool bombable(int t) {
    switch(t) {
      /* some level of danger */
    case T_EXIT:
    case T_SLEEPINGDOOR:
      /* useful */
    case T_LASER:

      /* obvious */
    case T_BROKEN:
    case T_GREY:
    case T_RED:
    case T_GREEN:

      /* a soft metal. ;) */
    case T_GOLD:

    case T_NS:
    case T_WE:
    case T_NW:
    case T_NE:
    case T_SW:
    case T_SE:
    case T_NSWE:
    case T_TRANSPONDER:
    case T_BUTTON:
    case T_BLIGHT:
    case T_GLIGHT:
    case T_RLIGHT:
    case T_REMOTE:

      /* ?? sure? */
    case T_BLUE:
      /* don't want walls made of this
	 ugly thing */
    case T_STOP:

      /* but doesn't count as picking it up */
    case T_HEARTFRAMER:


      /* ?? easier */
    case T_PANEL:
    case T_RPANEL:
    case T_GPANEL:
    case T_BPANEL:

    return true;

    case T_FLOOR:

      /* obvious */
    case T_HOLE:
    case T_ELECTRIC:
    case T_BLACK:
    case T_ROUGH:

      /* for symmetry with holes.
	 maybe could become holes,
	 but that is just more
	 complicated */
    case T_TRAP1:
    case T_TRAP2:
      

      /* useful for level designers */
    case T_LEFT:
    case T_RIGHT:
    case T_UP:
    case T_DOWN:
      
      /* Seems sturdy */
    case T_TRANSPORT:
    case T_ON:
    case T_OFF:
    case T_1:
    case T_0:

      /* made of metal */
    case T_STEEL:
    case T_BSTEEL:
    case T_RSTEEL:
    case T_GSTEEL:

    case T_LR:
    case T_UD:

    case T_SPHERE:
    case T_BSPHERE:
    case T_RSPHERE:
    case T_GSPHERE:

      /* shouldn't bomb the floorlike things,
	 so also their 'up' counterparts */
    case T_BUP:
    case T_BDOWN:
    case T_GUP:
    case T_GDOWN:
    case T_RUP:
    case T_RDOWN:
      
      return false;
    }      

    /* illegal tile */
    abort();
    return false;
  }

  bool hasframers() {
    for(int i = 0; i < w * h; i++) {
      if (tiles[i] == T_HEARTFRAMER) return true;
    }
    return false;
  }

};


#endif
