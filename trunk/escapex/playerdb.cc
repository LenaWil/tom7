
#include "playerdb.h"
#include "util.h"
#include "extent.h"
#include "prompt.h"
#include "chars.h"
#include "message.h"
#include "prefs.h"
#include "dirent.h"

#include "draw.h"

#define PLAYERDB_MAGIC "ESXD"

#define PDBTITLE YELLOW "Welcome to Escape!" POP \
                 " Select a player with the " \
                 BLUE "arrow keys" POP " and " BLUE "enter" POP ".\n" \
                 "To delete a player, press " BLUE "ctrl-d" POP ".\n \n"

#define MENUITEMS 3
enum pdbkind { K_PLAYER, K_NEW, K_IMPORT, K_QUIT, };

/* entries in the selector */
struct pdbentry {
  pdbkind kind;

  string name;
  string fname;

  int solved;

  static int height() { return TILEH + 8; }
  void draw(int x, int y, bool sel);
  string display(bool sel);
  player * convert();

  bool matches(char k);
  static player * none() { return 0; }

  static void swap (pdbentry * l, pdbentry * r) {
#   define SWAP(t,f) {t f ## _tmp = l->f; l->f = r->f; r->f = f ## _tmp; }
    SWAP(pdbkind, kind);
    SWAP(string, name);
    SWAP(string, fname);
    SWAP(int, solved);
#   undef SWAP
  }
  
  static int cmp_bysolved(const pdbentry & l,
			  const pdbentry & r) {
    if (l.kind < r.kind) return -1;
    if (l.kind > r.kind) return 1;
    if (l.solved > r.solved) return -1;
    else if (l.solved == r.solved) {
      if (l.name > r.name) return -1;
      else if (l.name == r.name) return 0;
      else return 1;
    }
    else return 1;
  }

};

struct playerdb_ : public playerdb {

  /* make db with one player, 'Default' */
  static playerdb_ * create();

  virtual void destroy();

  bool first;
  virtual bool firsttime() { return first; }

  virtual player * chooseplayer();

  virtual ~playerdb_() {}

  private:

  selector<pdbentry, player *> * sel;
  void addplayer(string);
  void delplayer(int);
  void insertmenu(int);
  void promptnew();
  void promptimport();

  static string makefilename(string name);
  static string safeify(string name);

};

/* assumes there's enough room! */
void playerdb_::insertmenu(int start) {
  sel->items[start++].kind = K_QUIT;
  sel->items[start++].kind = K_NEW;
  sel->items[start++].kind = K_IMPORT;
}

void pdbentry::draw(int x, int y, bool selected) {

  int ix = x + 4;
  int iy = y + 4;

  int tx = x + TILEW + 8;
  int ty = y + ((TILEW + 8) >> 1) - (fon->height >> 1);

  switch (kind) {

  default:
    fon->draw(tx, ty, "???");
    break;

  case K_IMPORT:
    drawing::drawtileu(ix, iy, TU_I, 0, screen);
    fon->draw(tx, ty, BLUE "Import / Recover Player");
    break;

  case K_NEW:
    drawing::drawtileu(ix, iy, TU_N, 0, screen);
    fon->draw(tx, ty, BLUE "New Player");
    break;

  case K_QUIT:
    drawing::drawtileu(ix, iy, TU_X, 0, screen);
    fon->draw(tx, ty, BLUE "Quit");
    break;

  case K_PLAYER:
    /* Draw the player graphic. Should actually animate the
       player that's selected. */
    drawing::drawguy(DIR_DOWN, ix, iy, 0, screen);
    
    fon->draw(tx, ty, display(selected));
    break;
  }
}

string pdbentry::display(bool sel) {
  string color = "";
  if (sel) color = BLUE;
  return color + name + (string)" " POP 
         "(" YELLOW + itos(solved) + (string)POP ")";
}

player * pdbentry::convert() {
  player * ret = player::fromfile(fname);

  if (!ret) {
    message::no(0, "Couldn't read player " + fname);
    return 0;
  } else {
    /* ensure that this player (which may be from an older version)
       has at least defaults for any new prefs */
    prefs::defaults(ret);
    return ret;
  }
}

bool pdbentry::matches(char k) {
  if (kind == K_PLAYER) 
    return (name.length() > 0) && ((name[0]|32) == k);
  else if (kind == K_IMPORT) return ((k | 32) == 'i');
  else if (kind == K_NEW) return ((k | 32) == 'n');
  else if (kind == K_QUIT) return ((k | 32) == 'x' ||
				   (k | 32) == 'q');
  /* ?? */
  else return false;
}

void playerdb_::destroy() {
  sel->destroy();
  delete this;
}

/* Read current directory, inserting any player file that's found.
   If there are none found, then create a "default" player and
   start over. */
playerdb_ * playerdb_::create() {
  
  playerdb_ * pdb = new playerdb_();
  extent<playerdb_> ep(pdb);

  /* need at least enough for the menuitems, and for the
     default player. */
  pdb->sel = selector<pdbentry, player *>::create(MENUITEMS);
  if (!pdb->sel) return 0;

  pdb->sel->title = PDBTITLE;


  DIR * d = opendir(".");
  if (!d) return 0;
  dirent * de;

  int n = 0;
  while ( (de = readdir(d)) ) {
    string f = de->d_name;
   
#   ifdef WIN32
    f = util::lcase(f);
#   endif

    /* only bother with .esp files, particularly
       to avoid importing backups */
    /* printf("%s...\n", f.c_str()); */
    if (util::endswith(f, ".esp")) {
      pdb->sel->resize(MENUITEMS + n + 1);
      pdb->sel->items[n].kind = K_PLAYER;
      pdb->sel->items[n].fname = f;
      player * p = player::fromfile(f);

      if (p) {
	pdb->sel->items[n].name = p->name;
	pdb->sel->items[n].solved = p->num_solutions();

	p->destroy();
      } else {
	pdb->sel->items[n].name = f + "  **" RED "ERROR" POP "**";
	pdb->sel->items[n].solved = -1;
      }

      n ++;
    }
  }

  /* no players found? */
  if (n == 0) {
    pdb->sel->resize(MENUITEMS);
    pdb->insertmenu(0);
    pdb->addplayer("Default");
    pdb->first = true;
  } else {
    pdb->insertmenu(n);
    pdb->first = false;
  }

  ep.release();
  return pdb;
}

string playerdb_::safeify(string name) {
  /* names can only contain certain characters. */

  string ou;
  
  for(unsigned int i = 0;
      i < name.length() &&
      ou.length () < 32;
      i++) {
    
    if ((name[i] >= 'A' &&
	 name[i] <= 'Z') ||
	(name[i] >= 'a' &&
	 name[i] <= 'z') ||
	(name[i] >= '0' &&
	 name[i] <= '9') ||
	name[i] == '_' ||
	name[i] == '-' ||
	name[i] == ' ' ||
	name[i] == '.' ||
	name[i] == '(' ||
	name[i] == ')' ||
	name[i] == '!' ||
	name[i] == '@') ou += (char)name[i];
  }

  return ou;
}

string playerdb_::makefilename(string name) {
  /* shorten to 8 chars, strip special characters,
     add .esp */

  string ou;
  
  for(unsigned int i = 0;
      i < name.length() && ou.length() <= 8;
      i++) {
    
    if ((name[i] >= 'A' &&
	 name[i] <= 'Z') ||
	(name[i] >= 'a' &&
	 name[i] <= 'z') ||
	(name[i] >= '0' &&
	 name[i] <= '9') ||
	name[i] == '_') ou += (char)name[i];
    else if (name[i] == ' ') ou += '_';
  }
  
  if (ou == "") ou = "player";

  ou += ".esp";

  /* XXX test if the file exists,
     and if it does, change the
     player filename. */

  if (util::existsfile(ou)) return "";

  return ou;
}

void playerdb_::addplayer(string name) {
  player * plr = player::create(name);
  if(plr) {

    /* can fail, for example, if the file exists */
    string fname = makefilename(name);
    if (fname != "") {

      sel->resize(sel->number + 1);

      plr->fname = fname;
      plr->writefile();

      /* one slack spot; initialize it */
      sel->items[sel->number - 1].kind = K_PLAYER;
      sel->items[sel->number - 1].solved = 0;
      sel->items[sel->number - 1].name = name;
      sel->items[sel->number - 1].fname = fname;

      return;
    } else {
      plr->destroy();
    }

  } 

  /* failed if we got here */
  message::quick(0, "Couldn't create player. Does file already exist?",
		 "OK", "", PICS XICON POP);

}

void playerdb_::delplayer(int i) {

  /* XXX delete player file from disk? */
  if (sel->items[i].kind == K_PLAYER) {

    util::toattic(sel->items[i].fname);

    int n = 0;
    for(int m = 0; m < sel->number; m ++) {
      if (m != i) {
	sel->items[n++] = sel->items[m];
      } 
    }
    
    sel->number = n;
    sel->selected = 0;
  }
}


typedef selector<pdbentry, player *> selor;

player * playerdb_::chooseplayer() {

  sel->sort(pdbentry::cmp_bysolved);

  sel->redraw();

  SDL_Event event;

  while ( SDL_WaitEvent(&event) >= 0 ) {

    /* control-something is handled 
       separately. */

    if (event.type == SDL_KEYDOWN &&
	(event.key.keysym.mod & KMOD_CTRL))
      switch(event.key.keysym.sym) {

      default:
	break;

	/* delete selected */
      case SDLK_d: {
	/* XXX use a more robust method here to detect the default player. */
	if (sel->items[sel->selected].name != "Default"
	    && sel->items[sel->selected].kind == K_PLAYER) {

	  string answer = 
	    prompt::ask(0,
			((string)PICS QICON POP " Really delete " BLUE +
			 sel->items[sel->selected].name +
			 (string)" " POP "(" YELLOW +
			 itos(sel->items[sel->selected].solved) +
			 (string)" " POP "solved)? (y/N) "));
	
	  if (answer.length() > 0 && (answer[0]|32) == 'y') {
	    delplayer(sel->selected);
	  }

	  sel->sort(pdbentry::cmp_bysolved);
	  sel->redraw();
	} else {

	  /* XXX should we even do anything here? */
	  message::no(0, "Can't delete default player or menu items!");
	  sel->redraw();

	}
	continue;
      }
	/* create new */
      case SDLK_n: {
	promptnew ();
	continue;
      }
      }
     

    /* otherwise, handle via default selector */
    selor::peres pr = sel->doevent(event);
    switch(pr.type) {
    case selor::PE_SELECTED:
      switch(sel->items[sel->selected].kind) {
      case K_PLAYER:
	return sel->items[sel->selected].convert();
      case K_QUIT:
	return 0; /* XXX? */
      case K_IMPORT:
	promptimport();
	continue;

      case K_NEW:
	promptnew();
	continue;
      }
      /* ??? */
      break;
      /* FALLTHROUGH */
    case selor::PE_EXIT: /* XXX */
    case selor::PE_CANCEL:
      return 0;
    default:
    case selor::PE_NONE:
      ;
    }
  }

  return 0;
}

void playerdb_::promptnew() {
  /* XXX could default to getenv(LOGNAME) on linux */
  string ssss = safeify(prompt::ask(0,
				    "Enter name for new player: "));
	
  if (ssss != "") {
    addplayer(ssss);
  }

  sel->sort(pdbentry::cmp_bysolved);
  sel->redraw();
}

/* FIXME there should be no need for this any more? */
/* maybe it could re-scan files that aren't .esp, to show
   backups? */
/* XXX this would be much nicer if it actually let
   you browse the directory for a player file */
void playerdb_::promptimport() {
#if 0
  prompt * pp = prompt::create();
  extent<prompt> ep(pp);

  pp->title = "Enter filename (" BLUE "*.esp" POP "): ";
  pp->posx = 30;
  pp->posy = 30;

  string ss = pp->select();
  /* XXX we should probably make a copy of the player file.
     if importing from an old version, we don't want the
     player file to still live in the previous version's
     directory! */
  player * pa = player::fromfile(ss);

  if (pa) {

    sel->resize(sel->number + 1);

    /* one slack spot; initialize it */
    sel->items[sel->number - 1].kind = K_PLAYER;
    sel->items[sel->number - 1].solved = pa->num_solutions();
    sel->items[sel->number - 1].name = pa->name;
    sel->items[sel->number - 1].fname = pa->fname;
    
    pa->destroy ();

    sel->sort(pdbentry::cmp_bysolved);
  } else if (ss != "") {
    message::no(0, "Can't read " RED + ss + POP ".");
  }
#endif

  message::no(0, 
	      "To import a player, just " BLUE "copy the .esp file" POP "\n"
	      "   into the escape directory and restart the game.");

  sel->redraw();
}

playerdb * playerdb::create() {
  return playerdb_::create();
}
