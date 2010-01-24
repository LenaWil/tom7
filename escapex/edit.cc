
#include "SDL.h"
#include "SDL_image.h"
#include <math.h>
#include <time.h>
#include "edit.h"
#include "sdlutil.h"
#include "draw.h"

#include "escapex.h"
#include "play.h"
#include "prompt.h"

#include "extent.h"
#include "util.h"
#include "edit.h"

#include "load.h"
#include "md5.h"

#include "message.h"
#include "menu.h"
#include "chars.h"

#define EDITORBGCOLOR 0xFF111122
#define SELRECTCOLOR 0x76, 0x12, 0xAA
#define SELRECTCOLOR2 0xAA, 0x40, 0xFF

#define LEVYSKIP 12

#define XOFF 0
#define YOFF (TILEH * 2 + LEVYSKIP)

#define XW (screen->w - XOFF)
#define YH (screen->h - YOFF)

int edit_menuitem[] =
  { 0 /* skip - show foreground tile */,
    0 /* skip - layer normal/alt */,
    0 /* skip - changed/not */,
    TU_SAVE, TU_SAVEAS, TU_LOAD,
    TU_TITLE, TU_AUTHOR, TU_SIZE,
    TU_PLAYERSTART, TU_CLEAR,
    TU_PLAY, TU_RANDOM, 
    TU_RANDTYPE,
    TU_ERASE_BOT,
    TU_FIRST_BOT,
    TU_DALEK,
    TU_HUGBOT,
    TU_BROKEN,
    TU_BOMB,
    TU_BOMBTIMER,
    TU_SLEEPWAKE,
    TU_PREFAB,
  };

int tileorder[] =
  {
  T_FLOOR, T_ROUGH, T_EXIT, T_BLUE, T_RED, T_GREY, T_GREEN, 
  T_GOLD, 
  T_BLACK,
  T_TRAP2, T_TRAP1, T_HOLE, 
  T_LASER, T_PANEL, 
  T_BPANEL, T_RPANEL, T_GPANEL,
  T_STOP, T_RIGHT, T_LEFT, T_UP, T_DOWN,
  T_ELECTRIC, T_ON, T_OFF, T_TRANSPORT, T_BROKEN, T_LR, T_UD, 
  T_0, T_1, 
  T_BUTTON,
  T_NS, T_NE, T_NW, T_SE, T_SW, T_WE, T_NSWE,
  T_TRANSPONDER, 
  
  T_REMOTE,
  T_BLIGHT, T_RLIGHT, T_GLIGHT, T_BUP, T_BDOWN,
  T_RUP, T_RDOWN, T_GUP, T_GDOWN, 

  T_BSPHERE, T_RSPHERE, T_GSPHERE, T_SPHERE,
  T_STEEL, T_BSTEEL, T_RSTEEL, T_GSTEEL, 

  T_HEARTFRAMER, T_SLEEPINGDOOR, 

  };

#define NTILEORDER ((int)(sizeof (tileorder) / sizeof (int)))

#define POS_CURRENT 0
#define POS_LAYER 1
#define POS_CHANGED 2
#define POS_RANDTYPE 13
#define POS_SAVE 3
#define POS_RANDOM 12
#define POS_ERASE_BOT 14
#define POS_FIRST_BOT 15
#define POS_BOMBTIMER 20
#define POS_SLEEPWAKE 21
#define POS_PREFAB 22
#define NUM_MENUITEMS 23

#define ispanel level::ispanel
#define needsdest level::needsdest

void editor::screenresize() {
  dr.width = XW;
  dr.height = YH;
  
  /* XXX not sure how to recalculate this ... */
  /* perhaps scroll so that the foreground tile is
     visible */
  tmenuscroll = 0;
}

void editor::fullclear(tile t) {
  for(int x = 0; x < dr.lev->w; x ++) {
    for(int y = 0; y < dr.lev->h; y ++) {
      dr.lev->settile(x, y, t);
    }
  }
  dr.lev->nbots = 0;
}

/* XXX limit to selection */
void editor::clear(tile bg, tile fg) {
  if (changed &&
      !message::quick(this,
		      "Clearing will destroy your unsaved changes.",
		      "Clear anyway",
		      "Don't clear")) {
    redraw();
    return;
  }

  /* don't allow fill with panels or transporters */
  if (needsdest(bg)) bg = T_FLOOR;
  if (needsdest(fg)) fg = T_BLUE;

  fullclear(bg);
  for(int x = 0; x < dr.lev->w; x ++) {
    dr.lev->settile(x, 0, fg);
    dr.lev->settile(x, dr.lev->h - 1, fg);
  }
  for(int y = 0; y < dr.lev->h; y ++) {
    dr.lev->settile(0, y, fg);
    dr.lev->settile(dr.lev->w - 1, y, fg);
  }
  
  changed = 0;
  redraw();
}

/* for debugging, since it pauses everything */
void editor::blinktile(int destx, int desty, Uint32 color) {
  int xx, yy;
  if (dr.onscreen(destx, desty, xx, yy)) {
    SDL_Rect dst;
    dst.x = xx;
    dst.y = yy;
    dst.w = TILEW;
    dst.h = TILEH;
    SDL_FillRect(screen, &dst, color);
  }
  SDL_Flip(screen);
  SDL_Delay(500);
}

void editor::draw() {

  /* check if we need to highlight a destination */
  int tx, ty;
  int sdx = -1, sdy = -1;
  if (dr.inmap(mousex, mousey, tx, ty)) {
    if (needsdest(layerat(tx, ty))) {
      dr.lev->getdest(tx, ty, sdx, sdy);
    }
  }

  sdlutil::clearsurface(screen, EDITORBGCOLOR);
  /* draw black for menu */
  { 
    SDL_Rect dst;
    dst.x = 0;
    dst.y = 0;
    dst.w = screen->w;
    dst.h = TILEH * 2;
    SDL_FillRect(screen, &dst, BGCOLOR);
  }

  int showw = (screen->w / TILEW) - 1;

  /* draw menu */

  /* could be showw + 1 */
  for(int j = 0; j < showw; j++) {

    if (j == POS_CURRENT) {
      dr.drawtile(j * TILEW, 0, current, 0);
    } else if (j == POS_LAYER) {
      drawing::drawtileu(j * TILEW, 0, layer?TU_LAYERALT:TU_LAYERNORMAL, 0);
    } else if (j == POS_CHANGED) {
      if (changed) drawing::drawtileu(j * TILEW, 0, TU_CHANGED, 0);
    } else if (j < NUM_MENUITEMS && edit_menuitem[j]) {
      drawing::drawtileu(j * TILEW, 0, edit_menuitem[j], 0);
    }

    /* draw extra info */
    if (j == POS_RANDTYPE) {
      fon->draw(j * TILEW + 14, 12, GREY + itos(randtype) + POP);
    } else if (j == POS_BOMBTIMER) {
      fon->draw(j * TILEW + 14, 12, 
		GREY + itos((int)currentbomb - (int)B_BOMB_0) + POP);
    }
  }

  /* disable menu items where appropriate */

  if (filename == "") {
    drawing::drawtileu(POS_SAVE * TILEW, 0, TU_DISABLED, 0);
  }

  if (!selection.w) {
    drawing::drawtileu(POS_PREFAB * TILEW, 0, TU_DISABLED, 0);
  }

  if (!dr.lev->nbots) {
    drawing::drawtileu(POS_FIRST_BOT * TILEW, 0, TU_DISABLED, 0);
    drawing::drawtileu(POS_ERASE_BOT * TILEW, 0, TU_DISABLED, 0);
    drawing::drawtileu(POS_SLEEPWAKE * TILEW, 0, TU_DISABLED, 0);
  }

  /* draw tile menu */
  int i;
  for(i = 0; i < showw; i++) {
    int tt = i + (showw * tmenuscroll);
    if (tt < NTILEORDER)
      dr.drawtile(i * TILEW, TILEH, tileorder[tt], 0);
  }

  drawing::drawtileu(i * TILEW, TILEH, TU_TILESUD, 0);

  /* always point him down. */
  dr.drawlev(layer);
  /* ? */
  dr.drawextra();

  /* always draw bot numbers */
  dr.drawbotnums();

  /* draw bomb timers */
  if (!dr.zoomfactor) {
    for(int b = 0; b < dr.lev->nbots; b++) {
      if (level::isbomb(dr.lev->bott[b])) {
	int bx, by;
	dr.lev->where(dr.lev->boti[b], bx, by);
	int bsx, bsy;
	if (dr.onscreen(bx, by, bsx, bsy)) {
	  string ss = RED + itos(level::bombmaxfuse(dr.lev->bott[b]));
	  fon->draw(bsx + ((TILEW - fon->sizex(ss))>>1),
		    bsy + ((TILEH - fon->height)>>1),
		    ss);
	}
      }
    }
  }

  /* draw destination, if it exists */
  /* XX maybe not if showdests? */
  {
    int px, py;
    if (sdx >= 0 && dr.onscreen(sdx, sdy, px, py)) {
      drawing::drawtileu(px, py, TU_TARGET, dr.zoomfactor);
    }
  }

  /* could be better at stacking arrows so that multiple ones
     on the same line could be distinguished */
  if (showdests) {
    dr.drawdests();
  }

  /* draw selection rectangle, if it exists */
  /* XXX this should allow the rectangle to be partially
     off-screen */
  if (selection.w > 0 &&
      selection.h > 0) {
    
    int px, py, pdx, pdy;
    if (dr.onscreen(selection.x, selection.y, px, py) &&
	dr.onscreen(selection.x + selection.w - 1,
		    selection.y + selection.h - 1,
		    pdx, pdy)) {
      
      pdx += (TILEW >> dr.zoomfactor) - 1;
      pdy += (TILEH >> dr.zoomfactor) - 1;

      sdlutil::drawline(screen, px, py, px, pdy, SELRECTCOLOR);
      sdlutil::drawline(screen, px, py, pdx, py, SELRECTCOLOR);
      sdlutil::drawline(screen, pdx, py, pdx, pdy, SELRECTCOLOR);
      sdlutil::drawline(screen, px, pdy, pdx, pdy, SELRECTCOLOR);


      sdlutil::drawline(screen, px + 1, py + 1, px + 1, pdy - 1, 
			SELRECTCOLOR2);
      sdlutil::drawline(screen, px + 1, py + 1, pdx - 1, py + 1, 
			SELRECTCOLOR2);
      sdlutil::drawline(screen, pdx - 1, py + 1, pdx - 1, pdy - 1, 
			SELRECTCOLOR2);
      sdlutil::drawline(screen, px + 1, pdy - 1, pdx - 1, pdy - 1, 
			SELRECTCOLOR2);

      

      sdlutil::drawline(screen, px + 2, py + 2, px + 2, pdy - 2, 
			SELRECTCOLOR);
      sdlutil::drawline(screen, px + 2, py + 2, pdx - 2, py + 2, 
			SELRECTCOLOR);
      sdlutil::drawline(screen, pdx - 2, py + 2, pdx - 2, pdy - 2, 
			SELRECTCOLOR);
      sdlutil::drawline(screen, px + 2, pdy - 2, pdx - 2, pdy - 2, 
			SELRECTCOLOR);


    }
  }

  /* coordinates of scroll */
  if (dr.scrollx > 0 ||
      dr.scrolly > 0) {
    
    fonsmall->draw(dr.posx + dr.margin + 1,
		   dr.posy + dr.margin - fonsmall->height,
		   itos(dr.scrollx) + ", " +
		   itos(dr.scrolly));
  }

}

void editor::tmenurotate(int n) {

  tmenuscroll += n;

  int showw = (screen->w / TILEW) - 1;

  if (tmenuscroll * showw >= NTILEORDER) tmenuscroll = 0;

  /* largest possible */
  if (tmenuscroll < 0) { 
    int tt = 0;
    while ((tt * showw) < NTILEORDER) {
      tt ++;
    }
    tmenuscroll = tt - 1;
  }

  redraw();
}

void editor::settitle() {
  string nt = prompt::ask(this, "Title for level: ",
			  dr.lev->title);

  dr.lev->title = nt;

  if (dr.lev->title == "") dr.lev->title = "Untitled";


  changed = 1;
  redraw ();
}

void editor::setauthor() {

  string s = prompt::ask(this,
			       "Author of level: ",
			       dr.lev->author);
  if (s != "") dr.lev->author = s;

  changed = 1;
  redraw();
}

/* XXX warn if saving into managed directory */
void editor::saveas() {

  string fn;
  if (filename == "") fn = (string)EDIT_DIR + (string) DIRSEP;
  else                fn = filename;

  string nfn = prompt::ask(this, "Filename: ", fn);

  /* if cancelled, don't do anything */
  if (nfn == "") { 
    redraw();
    return;
  }

  /* if level is untitled, get the title from this */
  if (dr.lev->title == "Untitled")
    dr.lev->title = util::fileof(nfn);

  filename = util::ensureext(nfn, ".esx");

  save();
}

void editor::playerstart() {
  clearselection();

  int x, y;
  
  if (getdest(x, y, "Click to choose player start.")) {
    if (!dr.lev->botat(x, y)) {
      dr.lev->guyx = x;
      dr.lev->guyy = y;
      changed = 1;
    } else {
      message::no(this, "Can't put player on bots!");
    }
  }

  redraw();
}

/* XXX target selection? */
void editor::erasebot() {
  clearselection();
  
  int x, y;
  if (getdest(x, y, (string)"Click on bot to erase.")) {

    if (!clearbot(x, y))
      dr.message = "No bot there!";

    changed = 1;
  }

  dr.lev->fixup_botorder();
  redraw ();
}

bool editor::clearbot(int x, int y) {

    int i;
    if (dr.lev->botat(x, y, i)) {
      /* reduce number of bots and shift every one bigger
	 than this one down */
      dr.lev->nbots --;
      for(int m = i; m < dr.lev->nbots; m ++) {
	dr.lev->bott[m] = dr.lev->bott[m + 1];
	dr.lev->boti[m] = dr.lev->boti[m + 1];
	dr.lev->botd[m] = dr.lev->botd[m + 1];
	dr.lev->bota[m] = dr.lev->bota[m + 1];
      }
      /* not necessary to make arrays smaller. */
      return true;
    } else return false;
}

void editor::firstbot() {
  int x, y;
  if (getdest(x, y, (string)"click on bot to make #1")) {

    int i;
    if (dr.lev->botat(x, y, i)) {
      level * l = dr.lev->clone ();
      extent<level> el(l);
      
      dr.lev->bott[0] = l->bott[i];
      dr.lev->botd[0] = l->botd[i];
      dr.lev->boti[0] = l->boti[i];
      dr.lev->bota[0] = l->bota[i];

      /* now copy rest */
      int r = 1;
      for(int b = 0; b < l->nbots; b++) {
	if (b != i) {
	  dr.lev->bott[r] = l->bott[b];
	  dr.lev->botd[r] = l->botd[b];
	  dr.lev->boti[r] = l->boti[b];
	  dr.lev->bota[r] = l->bota[b];
	  r ++;
	}
      }
    } else dr.message = "No bot there!";
  }
  redraw ();
}

void editor::sleepwake() {
  int x, y;
  if (getdest(x, y, (string)"click on bot sleep/wake")) {

    int i;
    if (dr.lev->botat(x, y, i)) {

      bot old = dr.lev->bott[i];
      bot dest = B_BROKEN;
      switch(old) {
      default:
	if (level::isbomb(old)) {
	  dr.message = RED "Can't sleep/wake bombs\n";
	  redraw();
	  return;
	} else {
	  message::bug(this, "sleep/wake not implemented for this bot");
	  redraw();
	  return;
	}
      case B_BROKEN:
	dr.message = RED "Can't sleep/wake broken bots\n";
	redraw();
	return;
      case B_DALEK: dest = B_DALEK_ASLEEP; break;
      case B_DALEK_ASLEEP: dest = B_DALEK; break;
      case B_HUGBOT: dest = B_HUGBOT_ASLEEP; break;
      case B_HUGBOT_ASLEEP: dest = B_HUGBOT; break;
      }

      dr.lev->bott[i] = dest;

    } else dr.message = "No bot there!";
  }

  dr.lev->fixup_botorder();
  redraw ();
}

void editor::placebot(bot b) {
  clearselection ();

  int x, y;
  
  string msg =
    (dr.lev->nbots < LEVEL_MAX_ROBOTS) ?
    ("Click to place bot of type " + itos((int)b)) :
    (RED "Out of bots!" POP " -- click existing bot to change type.");

  if (getdest(x, y, msg)) {

    int ai;
    if (dr.lev->playerat(x, y)) {
      message::no(this, "Can't put a bot on the player!");
      
    } else if (dr.lev->botat(x, y, ai)) {
      
      dr.lev->bott[ai] = b;
      changed = 1;

    } else {
      if (dr.lev->nbots < LEVEL_MAX_ROBOTS) {
	addbot(x, y, b);
      } else {
	message::no(this, 
		    "Maximum robots (" + itos(LEVEL_MAX_ROBOTS) + 
		    ") reached!");
	redraw();
      }
    } 
  }

  redraw();
}

/* must ensure there is space, and that
   there is not a bot or player on this spot already */
void editor::addbot(int x, int y, bot b) {
  int n = dr.lev->nbots + 1;
	  
  /* all clear; add new one */
  int * ni = (int*)malloc(sizeof(int) * n);
  bot * nt = (bot*)malloc(sizeof(bot) * n);
	
  for(int i = 0; i < dr.lev->nbots; i ++) {
    ni[i] = dr.lev->boti[i];
    nt[i] = dr.lev->bott[i];
  }
	
  ni[n - 1] = dr.lev->index(x, y);
  nt[n - 1] = b;
  free(dr.lev->boti);
  free(dr.lev->bott);
  dr.lev->boti = ni;
  dr.lev->bott = nt;
  dr.lev->nbots = n;
	
  /* need to update directions, too */
  free(dr.lev->botd);
  dr.lev->botd = (dir*)malloc(sizeof (dir) * n);
  { for(int z = 0; z < n; z ++) dr.lev->botd[z] = DIR_DOWN; }


  /* attribs always -1 except when playing */
  free(dr.lev->bota);
  dr.lev->bota = (int*)malloc(sizeof (int) * n);
  { for(int z = 0; z < n; z ++) dr.lev->bota[z] = -1; }


  dr.lev->fixup_botorder();
  changed = 1;
}

void editor::save() {
  clearselection ();

  fixup();

  if (filename != "") {

    string old = readfile(filename);

    string nstr = dr.lev->tostring();

    if (writefile(filename, nstr)) {
      dr.message = "Wrote " GREEN + filename + POP;
    } else {
      dr.message = RED "error writing to " + filename + POP;
      filename = "";
    }

    if (old != "") {
      /* if player has solution for the
	 level existing in the file that we're
	 overwriting, try it out on the new
	 file. (We may just be changing something
	 cosmetic!) */

      /* XXX should keep around a list of
	 candidate md5s. We get these whenever
	 we play or save. */

      string omd5 = md5::hash(old);

      string nmd5 = md5::hash(nstr);
      /* only try if level changed */
      if (omd5 != nmd5) {

	/* do not free */
	ptrlist<namedsolution> * sols = plr->solutionset(omd5);

	int rs = 0, rb = 0;
	for(; sols; sols = sols -> next) {
	  namedsolution * ns = sols->head;

	  if (ns && ns->sol && !ns->bookmark && 
	      level::verify(dr.lev, ns->sol)) {
	    /* It still works! */
	    
	    namedsolution ns2(ns->sol, (string)"(recovered) "
			      + ns->name, 
			      ns->author, time(0), false);
	    // setting def_candidate to true so we always add.
	    // XXX that parameter's description is nonsensical
	    plr->addsolution(nmd5, &ns2, true);
	    
	    rs ++;
	  } else if (ns && ns->sol && ns->bookmark) {
	    // setting def_candidate to true so we always add.
	    // XXX that parameter's description is nonsensical
	    plr->addsolution(nmd5, ns->clone(), true);
	    rb ++;
	  }
	  
	}

	if (rs + rb > 0) {
	  string s = rs?((string)YELLOW + itos(rs) + POP " solution"
			 + ((rs==1)?(string)"":(string)"s")
			 + ((rb)?(string)", ":(string)"")
			 ):"";
	  string b = rb?((string)YELLOW + itos(rb) + POP " bookmark"
			 + ((rb==1)?(string)"":(string)"s")
			 ):"";
	  dr.message += (string)ALPHA50 " (" BLUE "recovered " + s + b + 
	                       (string)POP ")" POP;
	  plr->writefile();
	}

      } else {
	dr.message += (string)" again " ALPHA50 GREY "(" + md5::ascii(nmd5) + ")" POP POP;
      }
    }     
    
    /* on success, we clear changed flag */
    changed = 0;

  } else {
    message::bug(this, 
		 "shouldn't be able to save with empty filename");
  }

  redraw();
}

/* XXX should warn if you load from a managed directory. */
/* target selection? */
void editor::load() {
  clearselection();

  loadlevel * ll = loadlevel::create(plr, EDIT_DIR, true, true);
  if (!ll) {
    message::quick(this, "Can't open load screen!", 
		   "Ut oh.", "", PICS XICON POP);
    redraw();
    return ;
  }
  string res = ll->selectlevel();
  string ss = readfile(res);
  ll->destroy ();

  /* allow corrupted files */
  level * l = level::fromstring(ss, true);

  if (l) { 
    dr.lev->destroy();
    dr.lev = l;
    filename = res;
    dr.message = ((string)"Loaded " + filename);

    fixup();
    changed = 0;
  } else {
    dr.message = ((string) RED "error loading " + res + POP);
  }
 
  redraw();
}

editor::~editor() {}

void editor::playlev() {
  /* XXX check result for 'exit' */
  fixup();
  
  play * pla = play::create();
  extent<play> ep(pla);
  
  /* grab md5 in case player makes bookmarks */
  string md5 = md5::hash(dr.lev->tostring());

  /* playresult res = */ pla->doplay_save(plr, dr.lev, saved, md5);
  
  /* has a different loop; might have resized */
  screenresize();
  redraw();
}

void editor::resize() {
  clearselection();

  string nw = itos(dr.lev->w);
  string nh = itos(dr.lev->h);

  textinput twidth;
  twidth.question = "Width";
  twidth.input = nw;
  twidth.explanation =
    "Width of the level in tiles.";

  textinput theight;
  theight.question = "Height";
  theight.input = nh;
  theight.explanation =
    "Height of the level in tiles.";

  okay ok;
  ok.text = "Change Size";
  
  ptrlist<menuitem> * l = 0;

  ptrlist<menuitem>::push(l, &ok);
  ptrlist<menuitem>::push(l, &theight);
  ptrlist<menuitem>::push(l, &twidth);

  menu * mm = menu::create(this, "Level Size", l, false);

  ptrlist<menuitem>::diminish(l);

  if (mm->menuize() == MR_OK) {
    int nnw = atoi(twidth.input.c_str());
    int nnh = atoi(theight.input.c_str());

    if (nnw > 0 && nnw <= LEVEL_MAX_WIDTH &&
	nnh > 0 && nnh <= LEVEL_MAX_HEIGHT &&
	(nnw * nnh <= LEVEL_MAX_AREA)) {
      dr.lev->resize(nnw, nnh);
      
      /* reset scroll position */
      dr.scrollx = 0;
      dr.scrolly = 0;
      
      changed = 1;
    } else {
      message::quick(this,
		     "Size too large/small", 
		     "Sorry", "");
      
    }
  } /* XXX else MR_QUIT */

  redraw();
}

void editor::edit(level * origlev) {
  
  if (origlev) {
    dr.lev = origlev->clone();
  } else {
    dr.lev = level::defboard(18, 10);
  }

  dr.scrollx = 0;
  dr.scrolly = 0;
  dr.posx = XOFF;
  dr.posy = YOFF;
  dr.width = XW;
  dr.height = YH;
  dr.margin = 12;

  clearselection();

  olddest = -1;

  mousex = 0;
  mousey = 0;
  changed = 0;

  SDL_Event event;

  dr.message = "";

  saved = solution::empty();

  fixup ();

  redraw ();

  for(;;) {
    while (SDL_PollEvent(&event)) {
      if (handle_video_event(this, event)) continue;

      switch(event.type) {

      case SDL_MOUSEMOTION: {
	/* some more efficient way to do this?? */
	/* we only need to redraw if something 
	   has changed like mousing over a tile
	   with a destination */

	SDL_MouseMotionEvent * e = (SDL_MouseMotionEvent*)&event;

	/* we do a lot of stuff here. set this flag if
	   we need to redraw at the end. */
	int yesdraw = 0;

	int omx = mousex;
	int omy = mousey;

	mousex = e->x;
	mousey = e->y;

	/* if mouse down, draw line of tiles.
	   don't do it if they need destinations. */
	int otx, oty;
	int ntx, nty;

	/* XXX how do I set this? */
	bool ctrl_held = false;

	/* right mouse button, or ctrl held ... */
	if (((e->state & SDL_BUTTON(SDL_BUTTON_RIGHT)) ||
	     ((e->state & SDL_BUTTON(SDL_BUTTON_LEFT)) &&
	      ctrl_held)) &&
	    selection.w > 0 &&
	    dr.inmap(mousex, mousey, ntx, nty)) {

	  /* change selection rectangle */
	  int nw = 1 + (ntx - selection.x);
	  int nh = 1 + (nty - selection.y);
	  
	  if (nw != selection.w ||
	      nh != selection.h) {

	    if (nw <= 0 || nh <= 0) { nw = nh = 0; }

	    selection.w = nw;
	    selection.h = nh;
	    redraw ();
	  }

	  /* left mouse button ... */
	  /* XXX if I start in the map, then I should
	     always draw to the edge, even if the end
	     is not in the map */
	} else if (!needsdest(current) &&
		   !donotdraw &&
		   e->state & SDL_BUTTON(SDL_BUTTON_LEFT) &&
		   dr.inmap(omx, omy, otx, oty) &&
		   dr.inmap(mousex, mousey, ntx, nty)) {

	  if (otx != ntx ||
	      oty != nty) {
	    /* draw line. */
	    line * sl = line::create(otx, oty, ntx, nty);
	    extent<line> el(sl);
	    
	    int cx = otx, cy = oty;
	    
	    do {
	      setlayer(cx, cy, current);

	    } while (sl->next(cx, cy));

	    changed = 1;
	    /* always draw */
	    yesdraw = 1;
	  } else {
	    /* draw pixel */
	    
	    if ((layer?(dr.lev->otileat(ntx, nty))
		 :(dr.lev->tileat(ntx, nty)))
		!= current) {
	      setlayer(ntx, nty, current);
	      yesdraw = 1;
	      changed = 1;
	    }

	  }
	}

	/* calculate the destination to draw,
	   if any. */
	int tx, ty;
	if (dr.inmap(mousex, mousey, tx, ty)) {
	  if (needsdest(layerat(tx, ty))) {
	    if (dr.lev->destat(tx, ty) != olddest) {
	      olddest = dr.lev->destat(tx, ty);
	      yesdraw = 1;
	    }
	    /* XXX unify with next case */
	  } else {
	    if (olddest != -1) {
	      olddest = -1;
	      yesdraw = 1;
	    } 
	  }
	} else {
	  if (olddest != -1) {
	    olddest = -1;
	    yesdraw = 1;
	  }
	}

	if (yesdraw) redraw();

	break;
      }
      case SDL_MOUSEBUTTONDOWN: {
	SDL_MouseButtonEvent * e = (SDL_MouseButtonEvent*)&event;

	/* any click in this state puts us in drawing mode. */
	donotdraw = false;

	if (e->button == SDL_BUTTON_MIDDLE) {

	  /* XXX would be nice if we could pair this with the event
	     and not the current status of the keyboard, alas... */
	  if (SDL_GetModState() & KMOD_CTRL) {
	    /* swap */
	    int tx, ty;
	    if (dr.inmap(e->x, e->y, tx, ty)) {
	      dr.lev->swapo(dr.lev->index(tx, ty));
	      redraw ();
	    }
	  } else {
	    /* eyedropper */
	    int tx, ty;
	    if (dr.inmap(e->x, e->y, 
			 tx, ty)) {
	      
	      current = layer?dr.lev->otileat(tx, ty):dr.lev->tileat(tx, ty);
	      
	      redraw();
	    }
	  }
	  
	} else if (e->button == SDL_BUTTON_RIGHT) {
	  /* Start drawing selection rectangle */
	  int tx, ty;
	  if (dr.inmap(e->x, e->y, tx, ty)) {
	    selection.x = tx;
	    selection.y = ty;
	    
	    selection.w = 1;
	    selection.h = 1;
	  } else selection.w = 0;
	  redraw ();

	} else if (e->button == SDL_BUTTON_LEFT) {

	  int showw = (screen->w / TILEW) - 1;

	  /* on tile menu? */
	  if (e->y >= TILEH &&
	      e->y < (2 * TILEH)) {

	    if (e->x >= (TILEW * showw) &&
		e->x < (TILEW * (showw + 1))) {
	      
	      if (e->y < TILEH + (TILEH >> 1))
		tmenurotate(-1);
	      else tmenurotate(1);

	    } else if (/* e->x always >= 0 && */
		       e->x < (showw * TILEW)) {
	      
	      int tt = (e->x / TILEW) + (tmenuscroll * showw);

	      if (tt >= 0 && tt < NTILEORDER) current = tileorder[tt];

	      redraw();

	    } /* else nothing. */
	    


	  } else if (/* e->y always >= 0 && */
		     e->y < TILEH) {
	    /* menu */

	    int n = e->x / TILEW;

	    dr.message = itos(n);

	    redraw();

	    if (n < NUM_MENUITEMS) {
	      
	      /*
		TU_SAVE, TU_SAVEAS, TU_LOAD,
		TU_TITLE, TU_AUTHOR, TU_SIZE,
		TU_PLAYERSTART, TU_CLEAR,
		TU_PLAY, TU_RANDOM,
	      */

	      if (n == POS_LAYER) {
		layer = !layer;
		redraw ();
	      } else switch(edit_menuitem[n]) {

	      case TU_SIZE:
		resize();
		break;

	      case TU_PLAYERSTART:
		playerstart();
		break;

	      case TU_DALEK:
		placebot(B_DALEK);
		break;

	      case TU_BOMB:
		placebot(currentbomb);
		break;

	      case TU_HUGBOT:
		placebot(B_HUGBOT);
		break;

	      case TU_BROKEN:
		placebot(B_BROKEN);
		break;

	      case TU_ERASE_BOT:
		erasebot();
		break;

	      case TU_FIRST_BOT:
		firstbot();
		break;

	      case TU_LOAD:
		load();
		break;

	      case TU_AUTHOR:
		setauthor();
		break;

	      case TU_TITLE:
		settitle();
		break;

	      case TU_RANDOM:
		dorandom();
		break;
		
	      case TU_RANDTYPE:
		randtype ++;
		randtype %= NUM_RANDTYPES;
		dr.message = ainame(randtype);
		redraw();
		break;
		
	      case TU_BOMBTIMER:
		next_bombtimer();
		break;

	      case TU_SAVEAS:
		saveas();
		break;
		
	      case TU_SLEEPWAKE:
		sleepwake();
		break;

	      case TU_PREFAB:
		prefab();
		break;

	      case TU_SAVE:
		if (filename == "") saveas();
		else save();
		break;

	      case TU_PLAY:
		playlev();
		break;

	      case TU_CLEAR:
		clear(T_FLOOR, (tile)current);
		break;
	      default: ;

	      }

	    } /* else outside menu */


	  } else {
	    int tx, ty;

	    clearselection();

	    if (dr.inmap(e->x, e->y, 
			 tx, ty)) {
	      /* drawing area */

	      int old = layerat(tx, ty);
	      setlayer(tx, ty, current);

	      if (needsdest(current)) {

		int xx, yy;
		if (getdest(xx, yy, "Click to set destination.")) {
		  dr.lev->setdest(tx, ty, xx, yy);
		} else {
		  setlayer(tx, ty, old);
		}
		olddest = dr.lev->destat(tx, ty);

	      }

	      changed = 1;
	      redraw();
	    }
	  }


	} else if (e->button == SDL_BUTTON_RIGHT) {
	  /* on tile menu? if so, rotate. */

	  if (e->y > TILEH &&
	      e->y <= (2 * TILEH)) {
	    tmenurotate(1);
	  }

	}
	
	break;
      }

      case SDL_QUIT: goto edit_quit;
      case SDL_KEYDOWN:
	switch(event.key.keysym.sym) {
	  
	case SDLK_F2:
	  settitle();
	  break;

	case SDLK_KP_MINUS:
	case SDLK_MINUS:
	case SDLK_PAGEUP:
	  tmenurotate(-1);
	  break;

	case SDLK_KP_PLUS:
	case SDLK_PLUS:
	case SDLK_EQUALS:
	case SDLK_PAGEDOWN:
	  tmenurotate(1);
	  break;
	  
	case SDLK_UP:
	case SDLK_DOWN:
	case SDLK_RIGHT:
	case SDLK_LEFT: {

	  dir d = DIR_NONE;
	  switch(event.key.keysym.sym) {
	  case SDLK_DOWN: d = DIR_DOWN; break;
	  case SDLK_UP: d = DIR_UP; break;
	  case SDLK_RIGHT: d = DIR_RIGHT; break;
	  case SDLK_LEFT: d = DIR_LEFT; break;
	  default: ; /* impossible - lint */
	  }

	  if ((event.key.keysym.mod & KMOD_SHIFT) &&
	      selection.w > 0) {

	    /* extend selection in that direction by one
	       row/column. */
	  
	    /* the theory here is to "do the right thing,"
	       but to explain the "right thing" with the
	       simplest possible rule as to what "right"
	       is. */

	    /* for the discussion here we will assume the
	       pattern is being extended on its right side. */

	    /* the first step is to detect a pattern.
	       this is done only with respect to the tiles
	       (not destinations) in the foreground and
	       background. bots and players are ignored as
	       well. Assume the sequence of tiles is S.
	       We then find the shortest prefix Sp such
	       that

	        S = Sp,...,Sp,S'
	            `---v---'
		      j occurrences (j >= 1)

	       and S' is a (possibly empty) proper prefix
	       of Sp. The pattern is then Sp. Since S' may
	       be empty, a unique shortest Sp exists for
	       any S. */

	    /* to extend, we simply place a column (#n) of
	       tiles aside the selection so that S'Sp[n] is
	       still a prefix of Sp. (this is also always
	       possible because S' is a *proper* prefix of
	       Sp). */

	    /* this explains everything except for the
	       destination of panels, teleports, and remotes. 
	       For a panel at index i within the new column Sp[n],
	       we look at the destinations of the occurrences
	       of that panel in Sp_0[n], Sp_1[n], .. Sp_j-1[n],
	       which we call D0..Dj-1. 
	       
	       If the delta d1-d0, d2-d1, ... is constant,
	       then the destination of the new panel is
	       j*delta + d0. Otherwise, we arbitrarily choose
	       d0. (we could instead perhaps reject this
	       patterning, and extend--we can always make
	       delta constant by making the whole thing one
	       pattern! but this may be a bit too crazy).
	       (Or, we could just put a stopsign or something
	       here to indicate that we couldn't make a
	       sensible panel--maybe that is better. */
	    
	    dir right = d;
	    dir down;
	    /* could use level::turnright? */
	    switch(right) {
	    default:
	    case DIR_RIGHT: down = DIR_DOWN; break;
	    case DIR_LEFT: down = DIR_UP; break;
	    case DIR_DOWN: down = DIR_LEFT; break;
	    case DIR_UP: down = DIR_RIGHT; break;
	    }

	    int width, height;
	    switch(right) {
	    default:
	    case DIR_LEFT:
	    case DIR_RIGHT: width = selection.w; height = selection.h; break;
	    case DIR_DOWN:
	    case DIR_UP: width = selection.h; height = selection.w; break;
	    }

	    /* the "top-left" according to the coordinate system */
	    int startx, starty;
	    switch(right) {
	    default:
	    case DIR_UP:
	      startx = selection.x;
	      starty = selection.y + selection.h - 1;
	      break;
	    case DIR_DOWN:
	      startx = selection.x + selection.w - 1;
	      starty = selection.y;
	      break;
	    case DIR_LEFT:
	      startx = selection.x + selection.w - 1;
	      starty = selection.y + selection.h - 1;
	      break;
	    case DIR_RIGHT:
	      startx = selection.x;
	      starty = selection.y;
	      break;
	    }

	    int drightx, drighty, ddownx, ddowny;
	    dirchange(right, drightx, drighty);
	    dirchange(down,  ddownx,  ddowny);

    
	    /* this is the beginning of the new column */
	    int destx = startx + (drightx * width);
	    int desty = starty + (drighty * width);

	    /* check that there's room to extend */
	    if (destx >= dr.lev->w ||
		desty >= dr.lev->h ||
		destx < 0 ||
		desty < 0) continue;

	    /* blinktile(destx, desty, 0xFF884499); */
    

	    /* determine pattern length "plen"
	       (must be at least 1, since selection is
	       non-empty) */
	    int plen = 1;
	    for (; plen <= width; plen ++) {
	      /* check that this is a legal pattern. if so,
		 it is the shortest, since we are checking
		 in order */

	      /* printf("try plen %d...\n", plen); */

	      /* number of pattern (prefixes) we need to
		 check. If it evenly divides plen, then
		 there are width/plen of them. But if there
		 is any partial pattern, we add that in. */
	      int max = (width / plen) + !!(width % plen);
	      for(int n = 0; n < max; n ++) {
		/* first column of pattern occurrence to check */
		int checkx = startx + (drightx * plen * n);
		int checky = starty + (drighty * plen * n);

		/*
		printf("  (n:%d) checkx %d, checky %d\n",
		       n, checkx, checky);
		*/

		/* now check the pattern here. */
		/* since it may be a prefix, we only go up
		   to "maxcol": */
		int maxcol = util::minimum(plen, width - (n * plen));
		/* printf("  ... maxcol = %d\n", maxcol); */
		for(int col = 0; col < maxcol; col ++) {
		  for(int row = 0; row < height; row ++) {
		    int offx = 
		      (col * drightx) +
		      (row * ddownx);

		    int offy =
		      (col * drighty) +
		      (row * ddowny);
		    
		    #if 0
		    printf("   compare %d/%d to %d/%d\n",
			   startx + offx, starty + offy,
			   checkx + offx, checky + offy);
		    blinktile(startx + offx, starty + offy, 
			      0xFF0000FF);
		    blinktile(checkx + offx, checky + offy, 
			      0xFFFF0000);
		    redraw();
		    #endif

		    /* must be equal in bg and fg */
		    if (
			! ((dr.lev->tileat(startx + offx,
					   starty + offy) ==
			    dr.lev->tileat(checkx + offx,
					   checky + offy)) &&

			   (dr.lev->otileat(startx + offx,
					    starty + offy) ==
			    dr.lev->otileat(checkx + offx,
					    checky + offy)))) {
		      /* printf("NOT EQUAL.\n"); */
		      /* then we fail; check next */
		      goto next_size;
		      
		    }
		    
		  }
		}
		
		/* check pattern occurrence #n */
	      }
	      /* success! */
	      break;
	    next_size: ;
	    }
	    /* printf("OK: plen is: %d\n", plen); */

	    /* make new column */
	    {
	      /* column offset within pattern */
	      int col = width % plen;
	      for(int row = 0; row < height; row ++) {
		int offx = (row * ddownx);
		int offy = (row * ddowny);

		int p = 
		  dr.lev->tileat(startx + (col * drightx) + offx,
				 starty + (col * drighty) + offy);

		dr.lev->settile(destx + offx,
				desty + offy, p);

		int op = 
		  dr.lev->otileat(startx + (col * drightx) + offx,
				  starty + (col * drighty) + offy);

		dr.lev->osettile(destx + offx,
				 desty + offy, op);

		if (needsdest(p) || needsdest(op)) {
		  int delta = 0;
		  /* need to find delta. */
		  /* even simpler: assume that delta is
		     constant (from the first gap). */

		  int origdest = 
		    dr.lev->destat(startx + (col * drightx) + offx,
				   starty + (col * drighty) + offy);
		  
		  if (width < (plen * 2)) delta = 0;
		  else {
		    int seconddest =
		      dr.lev->destat(startx + ((col + plen) * drightx) + 
				     offx,
				     starty + ((col + plen) * drighty) + 
				     offy);
		    
		    delta = seconddest - origdest;
		  }
  
		  /* then the new dest is delta * n + origdest */
		  int n = (width) / plen;
		  
		  /* printf("delta: %d, n: %d\n", delta, n); */


		  int de = delta * n + origdest;
		  if (de < 0) de = 0;
		  if (de >= dr.lev->w * dr.lev->h) 
		    de = (dr.lev->w * dr.lev->h) - 1;

		  int xxx, yyy;
		  dr.lev->where(de, xxx, yyy);
		  dr.lev->setdest(destx + offx, desty + offy, xxx, yyy);
		}
				
	      }
	    }

	    /* and extend pattern */
	    switch(d) {
	    default: break;
	    case DIR_RIGHT: selection.w ++; break;
	    case DIR_DOWN: selection.h ++; break;
	    case DIR_UP: selection.y --; selection.h ++; break;
	    case DIR_LEFT: selection.x --; selection.w ++; break;
	    }

	    redraw();

	  } else if ((event.key.keysym.mod & KMOD_CTRL) &&
		     selection.w > 0) {

	    int dx, dy;
	    dirchange(d, dx, dy);

	    /* tx, ty are the start of the destination
	       of this block move */
	    int tx, ty;
	    /* but first check that the far corner will
	       also be on the screen */
	    if (!dr.lev->travel(selection.x + selection.w - 1, 
				selection.y + selection.h - 1, 
				d, tx, ty)) break;


	    if (dr.lev->travel(selection.x, selection.y, d,
			       tx, ty)) {
	      /* easier if we clone. */
	      level * cl = dr.lev->clone();
	      extent<level> ecl(cl);

	      /* then blank out the region */
	      {
		for(int y = selection.y; y < selection.y + selection.h; y++) {
		  for(int x = selection.x; x < selection.x + selection.w; x++) {
		    dr.lev->settile(x, y, T_FLOOR);
		    dr.lev->osettile(x, y, T_FLOOR);
		    dr.lev->setdest(x, y, 0, 0);
		    dr.lev->setflag(x, y, 0);
		  }
		}
	      }

	      for(int y = selection.y; y < selection.y + selection.h; y++)
		for(int x = selection.x; x < selection.x + selection.w; x++) {

		  /* copy all the parts */
		  dr.lev->settile(x + dx, y + dy,
				  cl->tileat(x, y));

		  dr.lev->osettile(x + dx, y + dy,
				   cl->otileat(x, y));

		  {
		  int ddx, ddy;
		  cl->where(cl->destat(x, y), ddx, ddy);

		  /* if the destination is inside the
		     thing we're moving, then preserve it */
		  if ((needsdest(cl->tileat(x, y)) ||
		       needsdest(cl->otileat(x, y))) && 
		      ddx >= selection.x &&
		      ddx < (selection.x + selection.w) &&
		      ddy >= selection.y &&
		      ddy < (selection.y + selection.h)) {

		    ddx += dx;
		    ddy += dy;
		    
		  }

		  /* anyway copy dest */
		  dr.lev->setdest(x + dx, y + dy, ddx, ddy);
		  }
		  
		  /* finally, flags */
		  dr.lev->setflag(x + dx, y + dy,
				  cl->flagat(x, y));

		}

	      /* move player, bots */
	      if (dr.lev->guyx >= selection.x &&
		  dr.lev->guyy >= selection.y &&
		  dr.lev->guyx < (selection.x + selection.w) &&
		  dr.lev->guyy < (selection.y + selection.h)) {
		dr.lev->guyx += dx;
		dr.lev->guyy += dy;

		/* if moving over bot (on edge), delete it */
		if (dr.lev->guyx < selection.x ||
		    dr.lev->guyy < selection.y ||
		    dr.lev->guyx >= (selection.x + selection.w) ||
		    dr.lev->guyy >= (selection.y + selection.h)) {
		  int bi;
		  if (dr.lev->botat(dr.lev->guyx, dr.lev->guyy, bi)) {
		    dr.lev->bott[bi] = B_DELETED;
		  }
		}

	      }

	      {
		for(int i = 0; i < dr.lev->nbots; i ++) {

		  int bx, by;
		  dr.lev->where(dr.lev->boti[i], bx, by);
		  if (bx >= selection.x &&
		      by >= selection.y &&
		      bx < (selection.x + selection.w) &&
		      by < (selection.y + selection.h)) {
		    bx += dx;
		    by += dy;

		    /* destroy any bot we're overwriting
		       (but not if it's in the selection, because
		       then it will move, too) */
		    int bi;
		    if (bx < selection.x ||
			by < selection.y ||
			bx >= (selection.x + selection.w) ||
			by >= (selection.y + selection.h)) {
		      
		      if (dr.lev->botat(bx, by, bi)) {
			/* overwrite bot */
			dr.lev->bott[bi] = B_DELETED;
		      } else if (dr.lev->playerat(bx, by)) {
			/* Delete self if trying to
			   overwrite player! */
			dr.lev->bott[i] = B_DELETED;
		      }
		    }
		  }
		    
		    /* move bot (even if deleted) */
		  dr.lev->boti[i] = dr.lev->index(bx, by);
		}
	      }

	      /* move selection with it, but don't change size */
	      selection.x = tx;
	      selection.y = ty;

	      fixup();
	    } /* would move stay on screen? */


	    redraw();
	  } else {

	    /* move scroll window */
    
	    int dx, dy;
	    dirchange(d, dx, dy);
	    dr.scrollx += dx;
	    dr.scrolly += dy;
	    
	    dr.makescrollreasonable();
	    
	    redraw();
	    
	  }
	}
	  break;
	  
	default: ;
	  /* no match; try unicode */
	
	switch(event.key.keysym.unicode) {

	case SDLK_ESCAPE:
	  if (changed) {
	    if (message::quick(this,
			       "Quitting will destroy your unsaved changes.",
			       "Quit anyway.",
			       "Don't quit.")) {
	      goto edit_quit;
	    } else {
	      redraw();
	    }
	  } else goto edit_quit;

	case SDLK_RETURN:
	  /* XXX center scroll on mouse */
	  break;

	case SDLK_r:
	  dorandom();
	  break;

	case SDLK_z:
	  resize();
	  break;

	case SDLK_c:
	  clear(T_FLOOR, (tile)current);
	  break;

	case SDLK_v: /* XXX paste */
	  break;

	case SDLK_e:
	  playerstart();
	  break;

	case SDLK_o:
	  erasebot();
	  break;

	case SDLK_f:
	  firstbot();
	  break;

	case SDLK_i:
	  prefab();
	  break;

	case SDLK_w:
	  sleepwake();
	  break;

	case SDLK_m:
	  next_bombtimer();
	  break;

	case SDLK_k:
	  placebot(B_DALEK);
	  break;

	case SDLK_b:
	  placebot(currentbomb);
	  break;

	case SDLK_n:
	  placebot(B_BROKEN);
	  break;

	case SDLK_h:
	  placebot(B_HUGBOT);
	  break;

	case SDLK_u:
	  setauthor();
	  break;

	case SDLK_d:
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    clearselection();
	    redraw();
	  } else {
	    showdests = !showdests;
	    redraw ();
	  }
	  break;

	case SDLK_a:
	  if (event.key.keysym.mod & KMOD_CTRL) {
	    selection.x = 0;
	    selection.y = 0;
	    selection.w = dr.lev->w;
	    selection.h = dr.lev->h;
	    redraw();
	  } else {
	    saveas();
	  }
	  break;

	case SDLK_t:
	  settitle();
	  break;

	case SDLK_s:
	  if (filename == "") saveas();
	  else save();
	  break;

	case SDLK_p:
	  playlev();
	  break;

	case SDLK_l:
	  load();
	  break;

	case SDLK_y:
	  layer = !layer;
	  redraw();
	  break;

	  /* zoom */
	case SDLK_LEFTBRACKET:
	case SDLK_RIGHTBRACKET:
	  dr.zoomfactor += (event.key.keysym.unicode == SDLK_LEFTBRACKET)? +1 : -1;
	  if (dr.zoomfactor < 0) dr.zoomfactor = 0;
	  if (dr.zoomfactor >= DRAW_NSIZES) dr.zoomfactor = DRAW_NSIZES - 1;

	  /* scrolls? */
	  dr.makescrollreasonable();

	  redraw();
	  break;

	default:
	  break;
	} /* switch unicode */
	} /* switch sym */
	break;
      default:;
      }
    }
    
    SDL_Delay(25);
  }
 edit_quit:
  
  dr.lev->destroy();

  return;
}

void editor::next_bombtimer() {
  currentbomb = (bot)((int)currentbomb + 1);
  if ((int)currentbomb > (int)B_BOMB_MAX)
    currentbomb = B_BOMB_0;
  redraw();
}

bool editor::getdest(int & x, int & y, string msg) {
  clearselection ();

  SDL_Event event;

  dr.message = msg;

  redraw();

  for(;;) {
    while (SDL_PollEvent(&event)) {
      if (handle_video_event(this, event)) continue;

      switch(event.type) {

      case SDL_MOUSEBUTTONDOWN: {
	SDL_MouseButtonEvent * e = (SDL_MouseButtonEvent*)&event;

	/* we don't want this click (and drag) to result in
	   drawing. */
	donotdraw = true;

	if (e->button == SDL_BUTTON_LEFT) {
	  
	  int tx, ty;
	  if (dr.inmap(e->x, e->y, 
		       tx, ty)) {

	    x = tx;
	    y = ty;

	    dr.message = itos(tx) + (string)", " + itos(ty);
	    return 1;
	  }
	  /* other clicks cancel */
	} else {
	  dr.message = "";
	  return 0;
	}
	break;
      }

      case SDL_QUIT: return 0;
      case SDL_KEYDOWN:
	switch(event.key.keysym.sym) {
	case SDLK_UP: dr.scrolly --; break;
	case SDLK_DOWN: dr.scrolly ++; break;
	case SDLK_LEFT: dr.scrollx --; break;
	case SDLK_RIGHT: dr.scrollx ++; break;
	case SDLK_ESCAPE:
	  dr.message = "";
	  return 0;
	default:
	  break;
	}
	dr.makescrollreasonable();
	redraw();
	break;
      default:;
      }
    }
    
    SDL_Delay(25);
  }
  /* XXX unreachable */
  return 0;
}

/* fix various things before playing or saving. */
void editor::fixup () {

  /* XXX should fon->parens the texts */

  level * l = dr.lev;

  if (l->title == "") l->title = "Untitled";
  if (l->author == "") l->author = plr->name;
  if (l->author == "") l->author = "Anonymous";

  for(int i = 0; i < l->w * l->h; i ++) {

    /* always clear 'temp' flag. */
    l->flags[i] &= ~(TF_TEMP);

    /* make sure panel flag is set if tile is a panel.
       we have to also set the flag refinement: is it
       a regular, blue, green, or red panel?
    */
    /* first remove the flags no matter what. (we don't
       want to accumulate *extra* flags) */
    l->flags[i] &= ~(TF_HASPANEL | TF_RPANELL | TF_RPANELH);
    l->flags[i] &= ~(TF_OPANEL | TF_ROPANELL | TF_ROPANELH);

    /* restore them where appropriate */
    int ref;
    if (ispanel(l->tiles[i], ref)) {
      l->flags[i] |= TF_HASPANEL | 
	             ((ref & 1) * TF_RPANELL) |
	            (((ref & 2) >> 1) * TF_RPANELH);
    }

    if (ispanel(l->otiles[i], ref)) {
      l->flags[i] |= TF_OPANEL |
	             ((ref & 1) * TF_ROPANELL) |
	            (((ref & 2) >> 1) * TF_ROPANELH);
    }

    /* unset destination if not needed (makes
       smaller files because of longer runs) */
    if (!(needsdest(l->tiles[i]) ||
	  needsdest(l->otiles[i])))
      l->dests[i] = 0;

  }

  /* bots: remove deleted ones, normalize
     direction and attributes */
  {
    int bdi = 0;
    for(int bi = 0; bi < dr.lev->nbots; bi++) {
      if (dr.lev->bott[bi] >= 0 &&
	  dr.lev->bott[bi] < NUM_ROBOTS) {
	/* save bot */
	dr.lev->bott[bdi] = dr.lev->bott[bi];
	dr.lev->boti[bdi] = dr.lev->boti[bi];
	dr.lev->botd[bdi] = DIR_DOWN;
	/* always -1 */
	dr.lev->bota[bdi] = -1;
	bdi ++;
      }
    }
    
    dr.lev->nbots = bdi;
  }

  dr.lev->fixup_botorder();

  // XXX At this point the level should always
  // pass sanitize test. Check?

}

editor * editor::create(player * p) {

  editor * ee = new editor();

  ee->randtype = RT_MAZE;
  ee->plr = p;
  extent<editor> exe(ee);

  ee->current = T_BLUE;
  ee->layer = 0;
  ee->tmenuscroll = 0;
  
  ee->showdests = false;

  ee->changed = 0;

  ee->currentbomb = (bot)((int)B_BOMB_0 + 3);

  if (!ee->plr) return 0;

  exe.release();
  return ee;
}

