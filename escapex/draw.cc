
/* drawing a level */

#include "draw.h"
#include "sdlutil.h"
#include "chars.h"
#include "util.h"
#include "animation.h"
#include "message.h"
#include <time.h>
#include "extent.h"
 
#define TILEUTIL_FILE DATADIR "tileutil.png"
#define TILES_FILE DATADIR "tiles.png"
#define FONT_FILE DATADIR "font.png"
#define FONTSMALL_FILE DATADIR "fontsmall.png"

font * fon;
font * fonsmall;

SDL_Surface ** drawing::tiles = 0;
SDL_Surface ** drawing::tilesdim = 0;
SDL_Surface ** drawing::tileutil = 0;

/* the bottom of the load screen gives a preview of each level. This
   indicates the maximum width and height (in tiles) shown. */
/* XXX these should perhaps be parameters to drawsmall? */
#define PREVIEWHEIGHT (12 * (TILEH >> 2))
#define PREVIEWWIDTH (26 * (TILEW >> 2))

#define SHOWDESTCOLOR 0xAA, 0xAA, 0x33

bool drawing::loadimages() {
  /* PERF could be alpha=false. but the alphadim and shrink50
     routines rely on this being a 32 bit graphic. */
  SDL_Surface * tt = sdlutil::imgload(TILES_FILE);
  if (!tt) return 0;
  
  SDL_Surface * uu = sdlutil::imgload(TILEUTIL_FILE);
  if (!uu) return 0;

  /* XXX make dim levels for font too (pass in argument) */
  fon = font::create(FONT_FILE,
		     FONTCHARS,
 		     9, 16, FONTSTYLES, 1, 3);

  fonsmall = font::create(FONTSMALL_FILE,
			  FONTCHARS,
			  6, 6, FONTSTYLES, 0, 3);

  tiles = (SDL_Surface **)malloc(sizeof (SDL_Surface *) * DRAW_NSIZES);
  tilesdim = (SDL_Surface **)malloc(sizeof (SDL_Surface *) * DRAW_NSIZES);
  tileutil = (SDL_Surface **)malloc(sizeof (SDL_Surface *) * DRAW_NSIZES);

  if (!(tiles && tilesdim && tileutil)) return false;

  for(int z = 0; z < DRAW_NSIZES; z++) {
    tiles[z] = 0;
    tilesdim[z] = 0;
    tileutil[z] = 0;
  }

  tileutil[0] = uu;
  tiles[0] = tt;
  /* sdlutil::printsurfaceinfo(tiles[0]); */
  tilesdim[0] = sdlutil::alphadim(tiles[0]);
  if (!tilesdim[0]) return false;

  /* XXX call sdlutil::make_mipmaps */
  int last = 0;
  while(last < (DRAW_NSIZES - 1)) {
    last ++;
    tiles[last] = sdlutil::shrink50(tiles[last - 1]);
    if (!tiles[last]) return false;
    tilesdim[last] = sdlutil::alphadim(tiles[last]);
    if (!tilesdim[last]) return false;
    tileutil[last] = sdlutil::shrink50(tileutil[last - 1]);
    if (!tileutil[last]) return false;
  }

  if (!fon) return false;
  return true;
}

void drawing::destroyimages() {

  for(int i = 0; i < DRAW_NSIZES; i ++) {
    if (tiles && tiles[i]) SDL_FreeSurface(tiles[i]);
    if (tilesdim && tilesdim[i]) SDL_FreeSurface(tilesdim[i]);
    if (tileutil && tileutil[i]) SDL_FreeSurface(tileutil[i]);
  }
  
  free(tiles);
  free(tilesdim);
  free(tileutil);

  if (fon) fon->destroy();
  if (fonsmall) fonsmall->destroy ();

}

/* draw guy facing d at screen location x/y */
void drawing::drawguy(dir d,
		      int sx, int sy,
		      int zoomfactor,
		      SDL_Surface * surf, bool dead) {

  if (!surf) surf = screen;

  SDL_Surface * s = 0;

  if (dead && !zoomfactor) {
    /* just one dead frame */
    s = animation::lasered2;
  } else {
    switch(d) {
    default:
    case DIR_UP: s = animation::pic_guy_up[zoomfactor]; break;
    case DIR_DOWN: s = animation::pic_guy_down[zoomfactor]; break;
    case DIR_LEFT: s = animation::pic_guy_left[zoomfactor]; break;
    case DIR_RIGHT: s = animation::pic_guy_right[zoomfactor]; break;
    }
  }

  SDL_Rect dst;
  dst.x = sx;
  dst.y = sy - (GUY_OVERLAPY >> zoomfactor);
  
  SDL_BlitSurface(s, 0, surf, &dst);
}

void drawing::drawbot(bot b, dir d,
		      int sx, int sy,
		      int zoomfactor,
		      SDL_Surface * surf,
		      int data) {

  if (!surf) surf = screen;

  SDL_Surface * s = 0;
  int overlapy = 0;

  switch(b) {
  default:
    if (level::isbomb(b)) {
      
      switch(data) {
	/* XXX draw fuse in these cases */
	/* fuse high */
      default:
	overlapy = BOMB_OVERLAPY;
	s = animation::pic_bomb_lit[data][zoomfactor];
	break;
	/* not lit */
      case -1:
	overlapy = BOMB_OVERLAPY;
	s = animation::pic_bomb_still[zoomfactor];
	break;

      }
    } else {
      overlapy = 0;
      s = animation::error;
    }
    break;

  case B_BROKEN:
    overlapy = BROKEN_OVERLAPY;
    s = animation::pic_deadrobot[zoomfactor];
    break;

    /* assume one dir, same overlap as corresponding bot */
  case B_HUGBOT_ASLEEP:
    overlapy = HUGBOT_OVERLAPY;
    s = animation::pic_hugbot_asleep_down[zoomfactor]; break;
    break;

  case B_DALEK_ASLEEP:
    overlapy = DALEK_OVERLAPY;
    s = animation::pic_dalek_asleep_down[zoomfactor]; break;
    break;

  case B_HUGBOT:
    overlapy = HUGBOT_OVERLAPY;
    switch(d) {
    default:
    case DIR_UP: s = animation::pic_hugbot_up[zoomfactor]; break;
    case DIR_DOWN: s = animation::pic_hugbot_down[zoomfactor]; break;
    case DIR_LEFT: s = animation::pic_hugbot_left[zoomfactor]; break;
    case DIR_RIGHT: s = animation::pic_hugbot_right[zoomfactor]; break;
    }
    break;

  case B_DALEK:
    overlapy = DALEK_OVERLAPY;
    switch(d) {
    default:
    case DIR_UP: s = animation::pic_dalek_up[zoomfactor]; break;
    case DIR_DOWN: s = animation::pic_dalek_down[zoomfactor]; break;
    case DIR_LEFT: s = animation::pic_dalek_left[zoomfactor]; break;
    case DIR_RIGHT: s = animation::pic_dalek_right[zoomfactor]; break;
    }
    break;
    /* draw nothing */
  case B_BOMB_X: return ;
  case B_DELETED: return ;
  }

  SDL_Rect dst;
  dst.x = sx;
  dst.y = sy - (overlapy >> zoomfactor);
  
  SDL_BlitSurface(s, 0, surf, &dst);

}

void drawing::drawtile(int px, int py, int tl, int zf, 
		       SDL_Surface * surf, bool dim) {
  
  if (!surf) surf = screen;

  SDL_Rect src, dst;
  dst.x = px;
  dst.y = py;

  src.x = (TILEW >> zf) * (tl % SRCTILESW);
  src.y = (TILEH >> zf) * (tl / SRCTILESW);

  src.w = (TILEW >> zf);
  src.h = (TILEH >> zf);

  SDL_BlitSurface((dim?tilesdim:tiles)[zf], &src, surf, &dst);

}

void drawing::drawtileu(int px, int py, int tl, int zf,
			SDL_Surface * surf) {
  
  if (!surf) surf = screen;

  SDL_Rect src, dest;
  dest.x = px;
  dest.y = py;

  src.x = (TILEW >> zf) * tl;
  src.y = 0;

  src.w = (TILEW >> zf);
  src.h = (TILEH >> zf);

  SDL_BlitSurface(tileutil[zf], &src, surf, &dest);

}


/* make the scroll window reasonable, regardless of where
   the guy is. unreasonable scrolls show areas outside
   the level when there is something to show on the
   other side */
void drawing::makescrollreasonable() {

  int showw = (width - (margin + margin)) / (TILEW >> zoomfactor);
  int showh = (height - (margin + margin)) / (TILEH >> zoomfactor);

  if (scrollx > ((lev->w) - showw))
    scrollx = (lev->w) - showw;
  if (scrolly > ((lev->h) - showh))
    scrolly = (lev->h) - showh;

  if (scrollx < 0) scrollx = 0;
  if (scrolly < 0) scrolly = 0;

}

/* set the scroll window so that the guy is at least
   in the picture */
void drawing::setscroll() {
  int showw = (width - (margin + margin)) / (TILEW >> zoomfactor);
  int showh = (height - (margin + margin)) / (TILEH >> zoomfactor);

  /* default */
  int xpad = 3;
  int ypad = 3;

  if (showw < (xpad*2 + 1)) {
    xpad = (showw - 1) / 2;
  }

  if (showh < (ypad*2 + 1)) {
    ypad = (showh - 1) / 2;
  }

  /* when near the right, bottom, show at least
     pad+1 so that there are pad not including the
     guy himself */
  if (lev->guyx >= (scrollx + showw - (xpad + 1)))
    scrollx = (lev->guyx - showw) + (xpad + 1);
  if (lev->guyy >= (scrolly + showh - (ypad + 1)))
    scrolly = (lev->guyy - showh) + (ypad + 1);

  if (lev->guyx < (scrollx + xpad)) scrollx = lev->guyx - xpad;
  if (lev->guyy < (scrolly + ypad)) scrolly = lev->guyy - ypad;

  makescrollreasonable();

}

/* we sort the bots (and player) by 'depth' 
   in order to draw them in a consistent order. */
struct bb {
  int i; /* index */
  bot e; /* ent type */
  int d; /* direction */
  int a; /* extended data */
};

static int ydepth_compare(const void * l, const void * r) {
  bb * ll = (bb*) l;
  bb * rr = (bb*) r;
  return ll->i - rr->i;
}

void drawing::drawlev(int layer, /* dir facing, */
		      SDL_Surface * surf, bool dim) {

  if (!surf) surf = screen;

  /* number of tiles that can fit in either direction */
  int showw = (width - (margin + margin)) / (TILEW >> zoomfactor);
  int showh = (height - (margin + margin)) / (TILEH >> zoomfactor);

  /* draw arrows if scrolled. */
  
  /* actual width/height of tile area, then. */
  int actualw = showw * (TILEW >> zoomfactor);
  int actualh = showh * (TILEH >> zoomfactor);

  /* centered in the actual tile area */
  int centerx = (actualw / 2) + posx + margin;
  int centery = (actualh / 2) + posy + margin;

  if (!zoomfactor) {
    if (scrollx > 0) {
      fon->drawto(surf, posx + (fon->width >> 2), centery, PICS ARROWL);
    }
    /* XXX overlaps with title; put to the right?
       or maybe these should be on top of the tiles? */
    if (scrolly > 0) {
      fon->drawto(surf, centerx, posy - (fon->height >> 2), PICS ARROWU);
    }
    if ((scrollx + showw) < lev->w) {
      fon->drawto(surf, posx + actualw + margin, centery, PICS ARROWR);
    }
    if ((scrolly + showh) < lev->h) {
      fon->drawto(surf, centerx, posy + actualh + margin, PICS ARROWD);
    }
  }

  for(int xx = scrollx;
      xx < (showw + scrollx);
      xx++)
    for(int yy = scrolly;
	yy < (showh + scrolly);
	yy++) {

      if (xx < lev->w &&
	  yy < lev->h) {

	int tile = layer?lev->otileat(xx,yy):lev->tileat(xx, yy);

	/* draw the tile--but if it is the exit and we're standing
	   on it, draw the door open (even if we are dead) */

	/* XXX also when dimmed */
	if (!dim &&
	    tile == T_EXIT &&
	    ((lev->guyx == xx &&
	      lev->guyy == yy) || lev->botat(xx, yy))) {

	  drawtileu(posx + margin + (TILEW >> zoomfactor) * (xx - scrollx),
		    posy + margin + (TILEH >> zoomfactor) * (yy - scrolly),
		    TU_EXITOPEN, zoomfactor, surf);
	  
	} else {
	  drawtile(posx + margin + (TILEW >> zoomfactor) * (xx - scrollx),
		   posy + margin + (TILEH >> zoomfactor) * (yy - scrolly),
		   tile, zoomfactor, surf, dim);
	}

      } /* else ?  - scrolled off map */

    }

  int dx, dy;
  dir dd;
  bool isdead = lev->isdead(dx, dy, dd);

  /* if dead by laser, draw laser */
  if (isdead && dd != DIR_NONE) {
    /* dx, dy are a tile where the laser begins. 
       get screen coordinates. */
    
    int px = posx + margin + ((TILEW >> zoomfactor) * (dx - scrollx)) + (TILEH >> (zoomfactor + 1));
    int py = posy + margin + ((TILEH >> zoomfactor) * (dy - scrolly)) + (TILEW >> (zoomfactor + 1));

    /* and the guy */
    int gx = posx + margin + ((TILEW >> zoomfactor) * (lev->guyx - scrollx)) + (TILEH >> (zoomfactor + 1));
    int gy = posy + margin + ((TILEH >> zoomfactor) * (lev->guyy - scrolly)) + (TILEW >> (zoomfactor + 1));

    int chx, chy;
    dirchange(dd, chx, chy);

#   if 0
    char msg[128];
    sprintf(msg, " %d/%d "LRARROW" %d/%d (dir: %s = %d/%d)",
	    px, py, gx, gy, dirstring(dd).c_str(),
	    chx, chy);

    fon->drawto(surf, 2, surf->h - (3*(fon->height + 1)), msg);
#   endif

    /* advance laser so it starts at the edge of the tile
       instead of the center */
    px += chx * (TILEW >> (zoomfactor + 1));
    py += chy * (TILEH >> (zoomfactor + 1));

    sdlutil::slock(surf);
    
    while(px != gx || py != gy) {

      /* make sure it's in surf */
      if (!(px < 0 || py < 0 ||
	    px >= surf->w ||
	    py >= surf->h ||
	    /* and in scrollwindow */

	    px < (margin + posx) ||
	    py < (margin + posy) ||
	    px > (margin + posx + showw * (TILEW >> zoomfactor)) ||
	    py > (margin + posy + showh * (TILEH >> zoomfactor)))) {

	sdlutil::drawpixel(surf, px, py, 255, 255, 255);
	if (dd == DIR_UP || dd == DIR_DOWN) {
	  sdlutil::drawpixel(surf, px - 1, py, 255, 0, 0);
	  sdlutil::drawpixel(surf, px + 1, py, 255, 0, 0);
	} else {
	  sdlutil::drawpixel(surf, px, py - 1, 255, 0, 0);
	  sdlutil::drawpixel(surf, px, py + 1, 255, 0, 0);
	}

      }

      px += chx;
      py += chy;
    }

    sdlutil::sulock(surf);

  }

  /* XXX this is not really accurate. We should sort these by z(y)-order
     wrt to the guy as well */
  {
    bb * bots = (bb*) malloc((lev->nbots + 1) * sizeof(bb));

    {
      for(int i = 0; i < lev->nbots; i ++) {
	bots[i].i = lev->boti[i];
	bots[i].e = lev->bott[i];
	bots[i].d = lev->botd[i];
	bots[i].a = lev->bota[i];
      }
      /* and player */
      bots[lev->nbots].i = lev->index(lev->guyx, lev->guyy);
      bots[lev->nbots].e = B_PLAYER;
      bots[lev->nbots].d = lev->guyd;
      bots[lev->nbots].a = 0;
    }

    /* sort */
    qsort(bots, lev->nbots, sizeof (bb), ydepth_compare);

    /* now draw from bots array (guy is included) */
    for(int i = 0; i <= lev->nbots; i ++) {
      int bsx, bsy;
      int bx, by;
      lev->where(bots[i].i, bx, by);

      if (onscreen(bx, by, bsx, bsy)) {
	if (bots[i].e == B_PLAYER) 
	  drawguy(bots[i].d, bsx, bsy, 
		  zoomfactor, surf, isdead);
	else
	  drawbot(bots[i].e, bots[i].d, bsx, bsy,
		  zoomfactor, surf, bots[i].a);
      }
    }

    free(bots);
  }

}

void drawing::drawextra(SDL_Surface * surf) {
  if (!surf) surf = screen;

  if (!zoomfactor) {
    /* XXX should fon->parens and build these texts at load time */
    fon->drawto(surf, posx + margin + 2, (posy + (margin >> 1)) - fon->height,
		lev->title + (string)" " GREY "by " POP BLUE + 
		lev->author + POP);
    
    /* XXX wrong, should use height,posy */
    fon->drawto(surf, posx + 2, (surf->h) - (fon->height + 1), message);
  }
}

void drawing::drawbotnums(SDL_Surface * surf) {
  if (!surf) surf = screen;

  if (!zoomfactor) {
    for(int b = 0; b < lev->nbots; b++) {
      int bx, by;
      lev->where(lev->boti[b], bx, by);
      int bsx, bsy;
      if (onscreen(bx, by, bsx, bsy)) {
	string ss = YELLOW + itos(b + 1);
	fon->drawto(surf,
		    bsx + TILEW - fon->sizex(ss),
		    bsy + TILEH - fon->height,
		    ss);
      }
    }
  }
}

void drawing::drawdests(SDL_Surface * surf, bool shuffle) {
  if (!surf) surf = screen;

  sdlutil::slock(surf);
  for(int wx = 0; wx < lev->w; wx++)
    for(int wy = 0; wy < lev->h; wy++) {
      int sy, sx;
      if (onscreen(wx, wy, sx, sy)) {
	  
	sx += TILEW >> (1 + zoomfactor);
	sy += TILEH >> (1 + zoomfactor);

	if (level::needsdest(lev->tileat(wx, wy))
	    || level::needsdest(lev->otileat(wx, wy))) {
	  int d = lev->destat(wx, wy);
	  int dx, dy, px, py;
	  lev->where(d, dx, dy);

	  if (onscreen(dx, dy, px, py)) {

	    px += TILEW >> (1 + zoomfactor);
	    py += TILEH >> (1 + zoomfactor);

	    /* shake them around a little bit to reduce overlap */
	    if (shuffle) {
	      int maxw = TILEW >> (2 + zoomfactor);
	      int maxh = TILEH >> (2 + zoomfactor);
	      
	      px += (util::random() % maxw - (maxw >> 1));
	      py += (util::random() % maxh - (maxh >> 1));
	      sx += (util::random() % maxw - (maxw >> 1));
	      sy += (util::random() % maxh - (maxh >> 1));
	    }

	    /* draw line: dark bg first */
	    {
	      line * l = line::create(sx, sy, px, py);
	      extent<line> el(l);
		
	      int xx, yy;
	      while (l->next(xx, yy)) {
		  
#               define DARK(xxx, yyy) \
		  sdlutil::setpixel(surf, xxx, yyy, \
                                    sdlutil::mix2 \
				    (sdlutil::getpixel \
				     (surf, xxx, yyy), \
				    sdlutil::amask))
		
		DARK(xx-1, yy);
		DARK(xx+1, yy);
		DARK(xx, yy-1);
		DARK(xx, yy+1);
#               undef DARK
	      }
	    }

	    /* then inside */
	    {
	      line * l = line::create(sx, sy, px, py);
	      extent<line> el(l);
		
	      int xx, yy;
	      while (l->next(xx, yy)) {

		int r = 255 & ((wx * wy) ^ dx);
		int g = 255 & ((wx * 13 + dy) ^ ~wy);
		int b = 255 & ((dx * 99 + wy) ^ (101 * dy));

		sdlutil::drawpixel(surf, xx, yy,
				   r, g, b);
		  
	      }
	    }
	  }
	}
      }
    }
  sdlutil::sulock(surf);
}

bool drawing::inmap(int x, int y,
		    int & tx, int & ty) {

  int showw = (width - (margin + margin)) / (TILEW >> zoomfactor);
  int showh = (height - (margin + margin)) / (TILEH >> zoomfactor);

  if (x >= (margin + posx) &&
      y >= (margin + posy) &&
      x < (margin + posx) + (TILEW >> zoomfactor) * showw &&
      y < (margin + posy) + (TILEH >> zoomfactor) * showh) {

    /* in! */
    
    tx = ((x - (margin + posx)) / (TILEW >> zoomfactor)) + scrollx;
    ty = ((y - (margin + posy)) / (TILEH >> zoomfactor)) + scrolly;

    if (tx >= lev->w ||
	ty >= lev->h ||
	tx < 0 ||
	ty < 0) return false;

    return true;
  }

  return false;
}


bool drawing::onscreen(int x, int y,
		       int & tx, int & ty) {

  int showw = (width - (margin + margin)) / (TILEW >> zoomfactor);
  int showh = (height - (margin + margin)) / (TILEH >> zoomfactor);

  if (x >= scrollx &&
      y >= scrolly &&
      x < (scrollx + showw) &&
      y < (scrolly + showh)) {

    tx = margin + posx + ((x - scrollx) * (TILEW >> zoomfactor));
    ty = margin + posy + ((y - scrolly) * (TILEH >> zoomfactor));

    return 1;
  }

  return 0;
}

void drawing::drawsmall(int y, 
			int botmargin, Uint32 color,
			level * l, int solvemoves, string fname,
			ratestatus * votes,
			rating * myrating,
			int date, int speedrecord) {

  if (!l) {
    message::bug(0, "There's no level to draw small!");
    return;
  }

  drawing dr;
  dr.lev = l;
  dr.margin = 0;

# define MAXZOOMFACTOR 2

  /* choose the zoom factor to use. 

     we use the smallest zoom factor (largest tiles)
     that can draw the whole thing, with a max zoom
     of MAXZOOMFACTOR. */

  int zf = 0;

  while (zf < MAXZOOMFACTOR &&
	 (l->w * (TILEW >> zf) > PREVIEWWIDTH ||
	  l->h * (TILEH >> zf) > PREVIEWHEIGHT)) zf++;

  /* if it fits, center it */
  dr.posx = 4 + 
    ((l->w * (TILEW >> zf) >= PREVIEWWIDTH)?0 : 
     ((PREVIEWWIDTH - (l->w * (TILEW >> zf))) >> 1));

  dr.posy = y + 8 +
    ((l->h * (TILEH >> zf) >= PREVIEWHEIGHT)?0 : 
     ((PREVIEWHEIGHT - (l->h * (TILEH >> zf))) >> 1));

  dr.width = PREVIEWWIDTH;
  dr.height = PREVIEWHEIGHT;
  dr.zoomfactor = zf;

  dr.setscroll ();

  /* (let scroll be determined automatically) */
  dr.drawlev(0, screen);

  /* borders */
  int textx = 24 + PREVIEWWIDTH;

  SDL_Rect dst;
  dst.x = textx - 8;
  dst.y = y + 4;
  dst.h = botmargin - (16 + 8);
  dst.w = 2;
  SDL_FillRect(screen, &dst, color);
    
  int texty = (y + 8) - fon->height;

  /* sideinfo */

  fon->draw(textx, texty += fon->height,
	    (string)WHITE +
	    (string)YELLOW "Level:  " POP + l->title + 
	    (string)YELLOW " (" GREY + fname + (string) POP ")" POP POP);
  fon->draw(textx, texty += fon->height,
	    (string)YELLOW "Author: " BLUE + l->author + POP POP);

  fon->draw(textx, texty += fon->height,
	    (string)YELLOW "Size:   " + ((l->iscorrupted())?RED:GREEN) +
	    itos(l->w) + (string)GREY "x" POP +
	    itos(l->h) + POP POP +
	    (string)((l->iscorrupted())?RED" corrupted!"POP:""));

  texty += fon->height + 2;

  /* draw date, if there is one */
  if (date) {
    char buf[256];
    const time_t t = date;
    /* available on win32?? */
    strftime(buf, 250, "%d %b %Y", localtime(&t));
    fonsmall->draw(textx + fon->sizex("Author: "), 
		   texty, (string)GREY + (char*)buf);
  }

  texty += (fon->height >> 1) - 2;

  int ratey = texty;

  if (solvemoves) {
    /* XXX could draw this in color based on its relation
       to the speedrecord */
    string movecolor =
      ((speedrecord>0) && (speedrecord > solvemoves))?GREEN:GREY;
    
    fon->draw(textx, texty += fon->height,
	      (string)GREEN "Solved! " POP WHITE "(" GREY +
	      movecolor + itos(solvemoves) +
	      (string) POP " move" + 
	      (string)((solvemoves!=1)?"s":"") + POP ")" POP);
    if (speedrecord) {
      string rstring;
      if (speedrecord > 20000) rstring = RED + itos(speedrecord);
      else rstring = itos(speedrecord);

      fonsmall->draw(textx + fon->sizex("Solved! ("),
		     texty + fon->height,
		     GREY "Record: " + rstring);
    }
  } else {
    fon->draw(textx, texty += fon->height,
	      (string)GREY "Not solved." POP);
  }

  int ratex = textx + (22 * fon->width);

  if (myrating) {
    fonsmall->draw(ratex, ratey += fonsmall->height,
	      ((string)" Rated " +
	       RED   "difficulty " + itos(myrating->difficulty) + POP "  "
	       GREEN "style " + itos(myrating->style) + POP "  "
	       BLUE  "rigidity " + itos(myrating->rigidity) + POP));
	      /* XX show cooked */
  } else {
    fonsmall->draw(ratex, ratey += fonsmall->height, GREY "Not rated.");
  }

  /* space it a little */
  ratey += 4;

  if (votes && votes->nvotes > 0) {
    
    int gd = (int)((float)votes->difficulty / (float)votes->nvotes);
    int gs = (int)((float)votes->style      / (float)votes->nvotes);
    int gr = (int)((float)votes->rigidity   / (float)votes->nvotes);

    int gsol  = (int)((float)(100 * votes->solved) / (float)votes->nvotes);
    int gcook = (int)((float)(100 * votes->cooked) / (float)votes->nvotes);

    fonsmall->draw(ratex, ratey += fonsmall->height,
	      ((string) "Global " +
	       RED   "difficulty " + itos(gd) + POP "  "
	       GREEN "style " + itos(gs) + POP "  "
	       BLUE  "rigidity " + itos(gr) + POP));

    ratey += 2;
  
    fonsmall->draw(ratex, ratey += fonsmall->height,
		   ((string)
		    "       "
		    YELLOW + itos(gsol)  + "% " POP GREY "solved  " POP
		    YELLOW + itos(gcook) + "% " POP GREY "cooked  " POP
		    GREY "of " POP YELLOW + itos(votes->nvotes) + POP));

  } else {
    /* nothing */
  }

}

int drawing::smallheight() {
  return PREVIEWHEIGHT;
}
