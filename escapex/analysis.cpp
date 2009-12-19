
#include "analysis.h"
#include "extent.h"

/* could include traps. preference? */
bool analysis::isempty(int t) {
  switch (t) {
  case T_FLOOR:
  case T_ROUGH:
  case T_PANEL:
  case T_BDOWN:
  case T_RDOWN:
  case T_GDOWN:
  case T_BPANEL:
  case T_RPANEL:
  case T_GPANEL:
    return true;
  default:
    return false;
  }
}

onionfind * analysis::reachable (level * lev) {
  int size = lev->w * lev->h;
  onionfind * of = new onionfind(size);

  /* the algorithm is simple. each space begins in its own equivalence
     class. Then, for each "empty" space we place the guy there (a la
     transporter -- it's important that he presses any panel at that
     spot, and leaves any panel he's currently on). if he's dead, then
     we change nothing. if he can legally step in any of the four
     directions, and vice versa, then we union them and continue. 
     
     an empty space is: floor, rough, a panel, any colored floor that
     is 'down'
  */

  for(int y = 0; y < lev->h; y ++) {
    for(int x = 0; x < lev->w; x ++) {

      if (isempty(lev->tileat(x, y))) {
	level * cl = lev->clone ();
	extent<level> el(cl);

	cl->warp(cl->guyx, cl->guyy, x, y);

	/* mustn't be dead already! */
	int dummy; dir unused;
	if (cl->isdead(dummy, dummy, unused)) continue;

	for(dir d = FIRST_DIR; d <= LAST_DIR; d ++) {
	  level * cc = cl->clone ();
	  extent<level> ec(cc);

	  
	  /* we can't be walking off the map! */
	  int destx, desty;
	  if (!lev->travel(x, y, d, destx, desty)) continue;
	  
	  /* PERF could save some work by checking if they're
	     already unioned */
	  if (isempty(lev->tileat(destx, desty)) &&
	      cc->move(d) && !cc->isdead(dummy, dummy, unused)) {
	    /* good. now just check the opposite... */
	    level * co = cl->clone ();
	    extent<level> eec(co);

	    co->warp(cl->guyx, cl->guyy, destx, desty);
	    
	    if (co->move(dir_reverse(d)) &&
		!co->isdead(dummy, dummy, unused)) {

	      /* these two spots are mutually accessible,
		 so union them */

	      of->onion(lev->index(x, y),
			lev->index(destx, desty));
	      
	    }
	  } /* else can't move! */
	}

      } /* empty */

    }
  } /* loop over level */
  return of;
}

static bool separator(level * lev, int x, int y, 
		      int x1, int y1, int & x2, int & y2, 
		      int tile, bool search);


bool analysis::doessep(level * lev, int x, int y, 
		       int x1, int y1, int x2, int y2, int tile) {
  return separator(lev, x, y, x1, y1, x2, y2, tile, false);
}

bool analysis::issep(level * lev, int x, int y, 
		     int x1, int y1, int & x2, int & y2, int tile) {
  return separator(lev, x, y, x1, y1, x2, y2, tile, true);
}

static bool separator(level * lev, int x, int y, 
		      int x1, int y1, int & x2, int & y2, 
		      int tile, bool search) {

  /*
    printf("  separator(%d, %d, x1=%d, y1=%d, x2=%d, y2=%d, %s)\n",
    x, y, x1, y2, x2, y2, search?"SEARCH":"NOSEARCH");
  */

  /* must be currently empty.
     this could be relaxed to blocks
     that allow lasers through... */
  if (!analysis::isempty(lev->tileat(x, y))) return false;

  /* don't include degenerate cases */
  if (x == x1 && y == y1) return false;
  if (!search && (x1 == x2 && y1 == y2)) return false;
  if (!search && (x == x2 && y == y2)) return false;

  onionfind * orig = analysis::reachable(lev);
  extentd<onionfind> oe(orig);

  /* original equivalence class that we're in. */
  int oclass = orig->find(lev->index(x1, y1));

  level * nlev = lev->clone ();
  extent<level> le(nlev);
  
  nlev->settile(x, y, tile);

  onionfind * fresh = analysis::reachable(nlev);
  extentd<onionfind> oo(fresh);

# if 0
  {
    printf("\nseparate at %d/%d?? after:\n", x, y);
    for(int y = 0; y < lev->h; y ++) {
      for(int x = 0; x < lev->w; x ++) {
	printf("%4d ", fresh->find(nlev->index(x, y)));
      }
      printf("\n");
    }
  }
# endif

  int expect = fresh->find(nlev->index(x1, y1));

  /* now see if there are any newly separated regions. */

  if (search) {
    for(y2 = 0; y2 < lev->h; y2 ++)
      for(x2 = 0; x2 < lev->w; x2 ++) {
	/* check that they used to be the same */
	if (orig->find(lev->index(x2, y2)) == oclass) {

	  /* but now different! */
	  if(fresh->find(nlev->index(x2, y2)) != expect) {

	    /*
	      printf("may separate: oclass=%d, expect=%d, actual=%d\n",
	      oclass, expect,
	      fresh->find(nlev->index(x2, y2)) != expect);
	    */

	    /* also mustn't be the same as the one
	       we just added. */
	    if (x2 != x || y2 != y) return true;
	  }
	}
      }
    return false;
  } else {
    if (orig->find(lev->index(x2, y2)) == oclass &&
	fresh->find(nlev->index(x2, y2)) != expect &&
	(x2 != x || y2 != y)) return true;
    else return false;
  }

}
