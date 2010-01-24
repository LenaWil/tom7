
/* XXX This is deprecated (in favor of the bookmarks menu)
   and should be deleted. */

#ifndef __SMANAGE_H
#define __SMANAGE_H

#include "escapex.h"
#include "font.h"
#include "selector.h"
#include "player.h"
#include "util.h"

#define ALLSOLS_URL "/f/a/escape/allsols/"

struct smanage {
  static void manage(player *, string lmd5, level * lev);

  static void promptupload(drawable * below,
			   player *, string lmd5, 
			   solution * s, string msg,
			   string name,
			   bool speedrec = false);

  static void playback(player * plr, level * lev, namedsolution * ns);
};

#endif
