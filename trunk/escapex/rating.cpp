
#include "escapex.h"
#include "rating.h"

#include "player.h"
#include "draw.h"
#include "chars.h"
#include "message.h"
#include "md5.h"
#include "menu.h"

#include "client.h"
#include "commenting.h"
#include "smanage.h"

void rating::destroy() {
  delete this;
}

rating * rating::create () {
  return new rating ();
}

string rating::tostring () {
  /* just use one hex digit for each. */

  string r = "aa    ";

  r[0] = ((difficulty & 0xF) << 4) | (style & 0xF);
  r[1] = ((rigidity & 0xF) << 4) | (cooked & 0xF);
  r[2] = r[3] = r[4] = r[5] = 0;
  
  return r;
}

rating * rating::fromstring(string s) {
  if (s.length() != 6) return 0;

  rating * rat = create();

  if (!rat) return 0;

  rat->difficulty = (s[0] >> 4) & 0xF;
  rat->style = s[0] & 0xF;
  rat->rigidity = (s[1] >> 4) & 0xF; 
  rat->cooked = s[1] & 0xF;

  return rat;
}

/* below is ratescreen */

struct rsreal : public ratescreen {

  static rsreal * create(player * p, level * l, string levmd);

  virtual ~rsreal() {}

  virtual void rate();

  virtual void draw();
  virtual void screenresize() {}

  virtual void setmessage(string m) { msg = m; }

  virtual void destroy() {
    /* we don't own rating, player, or level */
    tx->destroy ();
    delete this;
  }
  
  private:
  player * plr;
  level * lev;

  string msg;

  textscroll * tx;
  string levmd5;
  /* number of moves solved in (0 = unsolved) */
  int nsolved;

  void redraw() {
    draw();
    SDL_Flip(screen);
  }

  /* current values for the rating. (or 0 if none yet) */

  rating * rat;

};

ratescreen * ratescreen::create(player * p, level * l, string levmd) {
  return rsreal::create(p, l, levmd);
}

rsreal * rsreal::create(player * p, level * l, string levmd) {
  rsreal * rr = new rsreal();
  if (!rr) return 0;

  rr->plr = p;
  rr->lev = l;
  rr->levmd5 = levmd;
 
  /* sol owned by player, don't free */
  solution * sol = rr->plr->getsol(levmd);
  rr->nsolved = sol?sol->length:0;

  /* might be 0, that's ok. */
  rr->rat = rr->plr->getrating(levmd);

  rr->below = 0;

  rr->tx = textscroll::create (fon);
  rr->tx->posx = 2;
  rr->tx->posy = 2;
  rr->tx->width = screen->w - 4;
  rr->tx->height = screen->h - (drawing::smallheight() + 24);

  return rr;
}

void rsreal::draw() {
  if (below) {
    below->draw();
  } else {
    /* clear back */
    sdlutil::clearsurface(screen, BGCOLOR);
  }

  fon->draw(2, 2, (string)(BLUE "Rating: " POP YELLOW) +
	    lev->title + POP);

  fon->draw(2, 2 + 3 * fon->height, msg);

  /* draw level thumbnail... */

  Uint32 color = 
    SDL_MapRGBA(screen->format, 0x22, 0x22, 0x44, 0xFF);
  int margin = drawing::smallheight() + 16;
  int y = (screen->h - margin) + 4 ;
  drawing::drawsmall(y,
		     margin,
		     color,
		     lev, nsolved, 
		     md5::ascii(levmd5),
		     /* XX pass in current rating? */
		     0, 0);

  /* draw current rating? */

}

void rsreal::rate() {

  /* XXX check that the player has registered */

  /* rat is the existing rating or 0 */

  redraw();

  label levname;
  levname.text = font::pad(lev->title, 50);
  label author;
  author.text = (string)"  by " + font::pad(lev->author, 45);

  int IND = 2;

  slider difficulty(0, 10, 22);
  difficulty.indent = IND;
  difficulty.pos = rat ? rat->difficulty : 5;
  difficulty.question = "Difficulty";
  difficulty.low = "easy";
  difficulty.high = "hard";
  difficulty.explanation = 
    "Choose your rating for this level's difficulty.\n"
    "You can rate it even if you haven't solved the level yet.";

  slider style(0, 10, 22);
  style.indent = IND;
  style.pos = rat ? rat->style : 5;
  style.question = "Style     ";
  style.low = "lame";
  style.high = "cool";
  style.explanation = 
    "How do you rate the composition of this level?\n"
    "How interesting is it to play? How does it look?\n"
    "How different is it from previously created levels?\n";

  slider rigidity(0, 10, 22);
  rigidity.indent = IND;
  rigidity.pos = rat ? rat->rigidity : 5;
  rigidity.question = "Rigidity  ";
  rigidity.low = "loose";
  rigidity.high = "tight";
  rigidity.explanation = 
    "Did this level have many solutions (loose) or few (rigid)?\n"
    "Rigidity is not necessarily good or bad.";

  bool old_cooked = rat? (!! rat->cooked):false;

  toggle cooked;
  cooked.indent = IND;
  cooked.disabled = nsolved==0;
  cooked.checked = old_cooked;
  cooked.question = "Cooked";
  cooked.explanation =
    "Do you think you solved this level the \"correct\" way?\n"
    "If you think you've found an alternate solution, then you've\n"
    "\"cooked\" it. Cooking really only applies to more rigid\n"
    "levels. (Please leave a comment describing the cook!)";

  toggle solved;
  solved.indent = IND;
  solved.disabled = true;
  solved.checked = (nsolved>0);
  solved.question = "Solved " GREY "(set automatically)" POP;
  /* XXX can't ever see this. 
     maybe disabled items should be selectable,
     but not modifiable? */
  solved.explanation =
    "Whether or not you've solved the level.\n"
    "This is set automatically.";

  okay ok;
  ok.text = "Change Rating";

  cancel can;
  can.text = "Cancel";
  
  ptrlist<menuitem> * l = 0;

  ptrlist<menuitem>::push(l, &can);
  ptrlist<menuitem>::push(l, &ok);
  ptrlist<menuitem>::push(l, &solved);
  ptrlist<menuitem>::push(l, &cooked);
  ptrlist<menuitem>::push(l, &rigidity);
  ptrlist<menuitem>::push(l, &style);
  ptrlist<menuitem>::push(l, &difficulty);
  ptrlist<menuitem>::push(l, &author);
  ptrlist<menuitem>::push(l, &levname);

  menu * mm = menu::create(this, "Change Your Rating", l, false);

  /* XXX look for MR_QUIT too */
  if (MR_OK == mm->menuize()) {

    /* Send to the server. */
  
    /* rat, if nonzero, is owned by the player so we
       don't need to free it. putrating will overwrite
       it or create a new one, if necessary. */

    rating * nr = rating::create();

    nr->difficulty = difficulty.pos;
    nr->style = style.pos;
    nr->rigidity = rigidity.pos;
    nr->cooked = cooked.checked;

    /* putrating takes ownership */
    plr->putrating(levmd5, nr);
    plr->writefile();

    /* send message to server */
    http * hh = client::connect(plr, tx, this);

    string res;

    bool success = 
      (hh != 0) && 
      client::rpc(hh, RATE_RPC,
		  /* credentials */
		  (string)"id=" +
		  itos(plr->webid) + 
		  (string)"&seql=" +
		  itos(plr->webseql) +
		  (string)"&seqh=" +
		  itos(plr->webseqh) +
		  /* rating */
		  (string)"&md=" + md5::ascii(levmd5) +
		  (string)"&diff=" + itos(nr->difficulty) +
		  (string)"&style=" + itos(nr->style) +
		  (string)"&rigid=" + itos(nr->rigidity) +
		  (string)"&cooked=" + itos((int)nr->cooked) +
		  (string)"&solved=" + itos((int)!!nsolved),
		  res);

    if (hh) hh->destroy();

    if (success) {

      int record = stoi(res);
      solution * ours = plr->getsol(levmd5);
      if (plr->webid && ours && ours->length < record) {
	/* beat the record! prompt to upload. */

	smanage::promptupload(0, plr, levmd5, ours, 
			      "You made a new speed record! " RED +
			      itos(record) + POP " " LRARROW " " GREEN +
			      itos(ours->length),
			      "Speed Record",
			      true);

      } else {

	/* XXX perhaps should prompt to upload solution 
	   (with comment) instead */
	/* first cook. prompt for comment. */
	if (nr->cooked && !old_cooked) {
	  commentscreen::comment(plr, lev, levmd5, true);
	} else {
	  /* only if no other pop-up */
	  message::quick(this, "Rating sent!",
			 "OK", "", PICS THUMBICON POP);
	}
      }

    } else {
      message::quick(this, "Unable to send rating to server: " RED + res,
		     "Cancel", "", PICS XICON POP);
    }

  } /* otherwise do nothing */

  ptrlist<menuitem>::diminish(l);
  mm->destroy ();

}

