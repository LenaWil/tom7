
#ifndef __DRAW_H
#define __DRAW_H


#include "SDL.h"
#include "SDL_image.h"
#include "level.h"
#include "font.h"
#include <math.h>
#include <string>
#include "rating.h"
#include "dirindex.h"

using namespace std;

/* size of zoom 0 tiles 
   we assume that these are
   evenly divisible by 
   2^(DRAW_NSIZES - 1) */
#define TILEW 32
#define TILEH 32

#define GUY_OVERLAPY 5
#define DALEK_OVERLAPY 5
#define HUGBOT_OVERLAPY 5
#define BROKEN_OVERLAPY 0
#define BOMB_OVERLAPY 5
#define MAX_OVERLAPY 5

#define BGCOLOR 0

/* width of source graphic in tiles */
#define SRCTILESW 16

/* utility tiles */
enum { TU_TARGET, TU_DISABLED, TU_WARNING,
       TU_LAYERNORMAL, TU_LAYERALT,
       TU_TILESUD,
       TU_SAVE, TU_SAVEAS, TU_LOAD,
       TU_TITLE, TU_AUTHOR, TU_SIZE, TU_PLAYERSTART,
       TU_CLEAR, TU_PLAY, TU_RANDOM, TU_RANDTYPE, 
       TU_CHANGED, 

       /* menu items */
       TU_X, TU_N, TU_I,
       TU_T, TU_1, TU_2, TU_3, TU_4, TU_P,
       
       TU_EXITOPEN,

       TU_ERASE_BOT, TU_FIRST_BOT,
       TU_DALEK, TU_BROKEN, TU_HUGBOT,

       TU_PLAYBUTTON, TU_PAUSEBUTTON,
       TU_FREVBUTTON, TU_FFWDBUTTON, 
       TU_FWDBUTTON, TU_REVBUTTON,

       TU_SLEEPWAKE, TU_PREFAB,
       TU_BOMB, TU_BOMBTIMER, 

       TU_SAVESTATE, TU_RESTORESTATE,
       TU_BOOKMARKS,
       TU_RESTART,
       TU_UNDO,       
       TU_REDO,
       TU_PLAYPAUSE,
       TU_PLAYPAUSE_PLAY,
       TU_FREDO,
       TU_FUNDO,
};

extern font * fon;
extern font * fonsmall;

struct drawing {

  /* initialized by loadimages:
     there are DRAW_NSIZES of these 
     in exponential backoff */
  static SDL_Surface ** tiles;
  static SDL_Surface ** guy;
  static SDL_Surface ** tilesdim;
  static SDL_Surface ** tileutil;

  /* call this once in the program. true on success */
  static bool loadimages();

  static void destroyimages();

  /* set these before using the functions
     below */

  /* space around the tiles in a level drawing */
  int margin;

  /* in tiles. 0,0 means no scroll. */
  int scrollx;
  int scrolly;

  int posx;
  int posy;
  int width;
  int height;

  /* must be in range 0..(DRAW_NSIZES - 1) */
  int zoomfactor;

  level * lev;

  string message;

  /* must set at least width, height, lev */
  drawing () : margin(0),
               scrollx(0), scrolly(0), posx(0), 
               posy(0), zoomfactor(0), lev(0) {}

  /* Drawing functions */

  /* screen coordinates */
  static void drawguy(whichguy g,
		      dir d,
		      int sx, int sy,
		      int zoomfactor,
		      SDL_Surface * surf = 0, bool dead = false);

  static void drawbot(bot b,
		      dir d,
		      int sx, int sy,
		      int zoomfactor,
		      SDL_Surface * surf = 0, 
		      int data = -1);

  /* if surface isn't supplied, then draw to screen. */
  static void drawtile(int px, int py, int tl, int zfactor = 0, 
		       SDL_Surface * surf = 0, bool dim = false);
  static void drawtileu(int px, int py, int tl, int zf = 0,
			SDL_Surface * surf = 0);

  void drawlev(int layer = 0,
	       SDL_Surface * surf = 0, bool dim = false);

  /* title, message, etc */
  void drawextra(SDL_Surface * surf = 0);

  /* debugging/editor/cheat */
  void drawdests(SDL_Surface * surf = 0, bool shuffle = false);
  
  void drawbotnums(SDL_Surface * surf = 0);

  /* make sure the scroll doesn't waste space by
     drawing nothing when it could be drawing
     something */
  void makescrollreasonable();

  /* scroll so that the guy is visible and somewhat
     centered */
  void setscroll();

  /* given screen coordinates x,y, return a tile
     if it is inside one on the screen */
  bool inmap(int x, int y,
	     int & tx, int & ty);

  /* given a tile x,y, return its
     screen coordinates if it is displayed currently. */
  bool onscreen(int x, int y,
		int & tx, int & ty);

  /* XXX this should probably be elsewhere */
  /* XXX combine y and botmargin, which have to agree anyway 
     ps. this function is much less complicated now */
  /* draw a small version of the level, with some info.
     used for the load screen and rating */
  static void drawsmall(int y, int botmargin, Uint32 color,
			level * l, int solvemoves, string fname,
			ratestatus * votes,
			rating * myrating, int date = 0,
			int speedrecord = 0);

  /* height of small drawings */
  static int smallheight();

};

#endif
