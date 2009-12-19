
#include "escapex.h"
#include "player.h"
#include "prefs.h"
#include "menu.h"
#include "draw.h"
#include "message.h"
#include "chars.h"

#define IND (fon->width)

void prefs::show(player * plr) {

  /* ------- user info -------- */
  /* XXX allow changing of name,
     which should notify the server */

  vspace spacer((int)(fon->height * 1.5f));

  /* ------- game prefs ------- */
  label game;
  game.text = PICS BARLEFT BAR BAR BARRIGHT POP 
               GREEN " Game Settings " POP
              PICS BARLEFT BAR BAR BARRIGHT POP ;
  
  toggle askrate;
  askrate.indent = IND;
  askrate.disabled = !plr->webid;
  askrate.question = "Prompt to Rate";
  askrate.checked = getbool(plr, PREF_ASKRATE);
  askrate.explanation =
    "If checked, then the game will prompt you to rate\n"
    "a level after solving it for the first time.\n"
    GREY "(Default: Checked)";

  toggle showtut;
  showtut.indent = IND;
  showtut.disabled = false;
  showtut.question = "Show Tutorial";
  showtut.checked = getbool(plr, PREF_SHOWTUT);
  showtut.explanation =
    "Show the tutorial on the main menu.\n"
    GREY "(Default: Checked)";

  toggle backup;
  backup.indent = IND;
  backup.disabled = false;
  backup.question = "Backup Player";
  backup.checked = getbool(plr, PREF_BACKUP_PLAYER);
  backup.explanation =
    "Back up player files every few days. They can be\n"
    "recovered from the player selection screen.\n"
    GREY "(Default: Checked)";

#if 0
  slider animspeed(0, ANIMATION_MAX_SPEED, 22);
  animspeed.indent = IND;
  animspeed.pos = getint(plr, PREF_ANIMATION_SPEED);
  animspeed.question = "Animation Speed";
  animspeed.low = "slower";
  animspeed.high = "faster    off ^^";
  animspeed.explanation = 
    "Speed of animation in the game. If set to maximum,\n"
    "animation will be disabled for snappiest possible action.";
#endif

  toggle animon;
  animon.indent = IND;
  animon.checked = getbool(plr, PREF_ANIMATION_ENABLED);
  animon.question = "Enable Animation";
  animon.explanation = 
    "Draw animations when playing. Recommended unless you are\n"
    "extremely impatient.\n"
    GREY "(Default: Checked)";

  toggle optsol;
  optsol.indent = IND;
  optsol.checked = getbool(plr, PREF_OPTIMIZE_SOLUTIONS);
  optsol.question = "Optimize Solutions";
  optsol.explanation = 
    "After you solve a level, the game will automatically try\n"
    "to optimize your solution to make it shorter.\n"
    GREY "(Default: Checked)";

  /* ------- network ---------- */
  label network;
  network.text = 
    PICS BARLEFT BAR BAR BARRIGHT POP 
       GREEN " Network Settings " POP
    PICS BARLEFT BAR BAR BARRIGHT POP; 

  textinput servername;
  servername.indent = IND;
  servername.question = "Server:";
  servername.input = getstring(plr, PREF_SERVER);
  servername.explanation =
    "This is the internet name of the server that Escape connects\n"
    "to in order to upgrade, register, and get new levels.\n"
    GREY "(Default: escape.spacebar.org)";

  toggle altconnect;
  altconnect.indent = IND;
  altconnect.checked = getbool(plr, PREF_ALTCONNECT);
  altconnect.question = "Alternate Connect";
  altconnect.explanation =
    "If this option is selected, then Escape will connect on an\n"
    "alternate port, which may bypass troublesome proxies.\n"
    GREY "(Default: Unchecked)";

  toggle debugnet;
  debugnet.indent = IND;
  debugnet.checked = getbool(plr, PREF_DEBUG_NET);
  debugnet.question = "Debug Network";
  debugnet.explanation =
    "Records debugging information about the networking process\n"
    "in a file. " RED "NOT RECOMMENDED" POP " for normal users.\n"
    GREY "(Default: Unchecked)";

  okay ok;
  ok.text = "Change Preferences";

  cancel can;
  can.text = "Cancel";

  ptrlist<menuitem> * l = 0;

  ptrlist<menuitem>::push(l, &can);
  ptrlist<menuitem>::push(l, &ok);
  ptrlist<menuitem>::push(l, &spacer);

  ptrlist<menuitem>::push(l, &debugnet);
  ptrlist<menuitem>::push(l, &altconnect);
  ptrlist<menuitem>::push(l, &servername);
  ptrlist<menuitem>::push(l, &network);
  ptrlist<menuitem>::push(l, &spacer);

  ptrlist<menuitem>::push(l, &optsol);
  ptrlist<menuitem>::push(l, &animon);
  ptrlist<menuitem>::push(l, &backup);
  ptrlist<menuitem>::push(l, &showtut);
  ptrlist<menuitem>::push(l, &askrate);
  ptrlist<menuitem>::push(l, &game);


  menu * mm = menu::create(0, "Escape Preferences Menu", l, false);

  resultkind res = mm->menuize();

  ptrlist<menuitem>::diminish(l);
  mm->destroy ();

  /* XXX check MR_QUIT */
  if (res == MR_OK) {
    putstring(plr, PREF_SERVER, servername.input);
    putbool(plr, PREF_ALTCONNECT, altconnect.checked);
    putbool(plr, PREF_ASKRATE, askrate.checked);
    putbool(plr, PREF_SHOWTUT, showtut.checked);
    putbool(plr, PREF_BACKUP_PLAYER, backup.checked);
    putbool(plr, PREF_DEBUG_NET, debugnet.checked);
    putbool(plr, PREF_ANIMATION_ENABLED, animon.checked);
    putbool(plr, PREF_OPTIMIZE_SOLUTIONS, optsol.checked);

    /* prefs may have changed, so write */
    plr->writefile();
  }
}

void prefs::defaults(player * plr) {
  
  chunks * ch = plr->getchunks();
  
  if (!ch->get(PREF_SERVER))
    putstring(plr, PREF_SERVER, DEFAULT_SERVER);

  if (!ch->get(PREF_ALTCONNECT))
    putbool(plr, PREF_ALTCONNECT, false);

  if (!ch->get(PREF_ASKRATE))
    putbool(plr, PREF_ASKRATE, true);

  if (!ch->get(PREF_SHOWTUT))
    putbool(plr, PREF_SHOWTUT, true);

  if (!ch->get(PREF_BACKUP_PLAYER))
    putbool(plr, PREF_BACKUP_PLAYER, true);

  if (!ch->get(PREF_DEBUG_NET))
    putbool(plr, PREF_DEBUG_NET, false);

  if (!ch->get(PREF_ANIMATION_ENABLED))
    putbool(plr, PREF_ANIMATION_ENABLED, true);

  if (!ch->get(PREF_OPTIMIZE_SOLUTIONS))
    putbool(plr, PREF_OPTIMIZE_SOLUTIONS, true);

}

void prefs::putstring(player * plr, unsigned int key, string s) {
  plr->getchunks()->insert(new chunk(key, s));
}

void prefs::putbool(player * plr, unsigned int key, bool b) {
  plr->getchunks()->insert(new chunk(key, b));
}

void prefs::putint(player * plr, unsigned int key, int i) {
  plr->getchunks()->insert(new chunk(key, i));
}

int prefs::getint(player * plr, unsigned int k) {
  chunk * c = plr->getchunks()->get(k);

  if (c && c->type == CT_INT) {
    return c->i;
  } else {
    printf("c: %p\n", c);
    if (c) printf("c->type %d\n", c->type);
    message::bug(0, "int pref unavailable: " RED + itos(k));
    return 0;
  }
}

bool prefs::getbool(player * plr, unsigned int k) {
  chunk * c = plr->getchunks()->get(k);

  if (c && c->type == CT_BOOL) {
    return (bool)c->i;
  } else {
    message::bug(0, "bool pref unavailable: " RED + itos(k));
    return false;
  }
}

string prefs::getstring(player * plr, unsigned int k) {
  chunk * c = plr->getchunks()->get(k);

  if (c && c->type == CT_STRING) {
    return c->s;
  } else {
    message::bug(0, "string pref unavailable: " RED + itos(k));
    return "";
  }
}
