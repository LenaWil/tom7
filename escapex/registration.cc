
#include "registration.h"
#include "client.h"
#include "extent.h"
#include "draw.h"

struct registration_ : public registration {
  registration_() {}

  virtual void registrate();

  virtual void screenresize();
  virtual void draw();
  void redraw() {
    draw ();
    SDL_Flip (screen);
  }

  virtual void destroy() {
    tx->destroy();
    delete this;
  }

  void say(string s) {
    if (tx) {
      tx->say(s);
      redraw();
    }
  }

  textscroll * tx;
  player * plr;
};

registration * registration::create(player * p) {
  registration_ * r = new registration_();
  r->plr = p;
  r->tx = textscroll::create(fon);
  return r;
}

void registration_::registrate() {

  http * hh = client::connect(plr, tx, this);
  if (!hh) { 
    message::quick(this,
		   "Couldn't connect to server.",
		   "Sorry", "", PICS XICON POP);
    return;
  }

  extent<http> eh(hh);

  /* XXX again, need a better way to detect this */
  if (plr->name == "Default") {
    message::quick(this, 
		   "You can't register with the default player.",
		   "Sorry", "", PICS XICON POP);
    return;
  }

  int tries=2;

  string res;
  while (tries--) {
    int seql = util::random();
    int seqh = util::random() ^ (((int)SDL_GetTicks() << 16) |
				 ((int)SDL_GetTicks() >> 16));

    seql = abs(seql);
    seqh = abs(seqh);

    say("try " + itos(seql) + " " + itos(seqh) + (string)"...");

    if (client::rpc(hh, REGISTER_RPC, 
		    (string) "seql=" + itos(seql) +
		    (string)"&seqh=" + itos(seqh) +
		    (string)"&name=" + httputil::urlencode(plr->name),
		    res)) {
      
      int id = stoi(res);
      if (id) {
	plr->webid = id;
	plr->webseql = seql;
	plr->webseqh = seqh;

	if (plr->writefile()) {
	  say ((string)"success! " GREEN + res);
	  message::quick(this,
			 (string)"You are registered as player " 
			 YELLOW "#" + itos(id),
			 "OK!", "", PICS THUMBICON POP);
	  return;
	} else {
	  say (RED "can't write player file...?");
	}
      } else {
	say ((string)"non-number response? [" RED + res + POP "]");
      }
    } else {
      say ((string)"fail: [" RED + res + POP "]");
    }
  }

  /* give up ... */

  message::no(this, 
	      "Unable to register:\n"
	      "     " RED + res + POP "\n"
	      "   Try again later!");
		 
  return;
}

void registration_::screenresize() {
  /* XXX resize tx */
}

void registration_::draw() {
  sdlutil::clearsurface(screen, BGCOLOR);
  tx->draw();
}
