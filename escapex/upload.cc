
#include "upload.h"
#include "client.h"
#include "http.h"
#include "message.h"
#include "draw.h"
#include "md5.h"
#include "optimize.h"

struct ulreal : public upload {
  static ulreal * create ();
  virtual ~ulreal() {}


  virtual upresult up(player * p, string file, string);

  void redraw() {
    draw ();
    SDL_Flip (screen);
  }

  void say(string s) {
    if (tx) {
      tx->say(s);
      redraw();
    }
  }

  virtual void destroy() {
    if (tx) tx->destroy();
    delete this;
  }

  textscroll * tx;
  player * plr;

  virtual void draw();
  virtual void screenresize();

};

upload * upload::create() {
  return ulreal::create();
}

ulreal * ulreal::create() {
  ulreal * ur = new ulreal();
  if (!ur) return 0;
  extent<ulreal> eu(ur);

  ur->tx = textscroll::create(fon);
  if (!ur->tx) return 0;

  ur->tx->posx = 5;
  ur->tx->posy = 5;
  ur->tx->width = screen->w - 10;
  ur->tx->height = screen->h - 10;

  eu.release();
  return ur;
}

upresult ulreal::up (player * p, string f, string text) {
  redraw();

  string levcont = util::readfilemagic(f, LEVELMAGIC);

  plr = p;

  level * lev = level::fromstring(levcont);
  if (!lev) return UL_FAIL;

  extent<level> el(lev);
  
  string md5c = md5::hash(levcont);


  /* don't free soln */
  solution * slong;
  if (! ((slong = plr->getsol(md5c)) && 
      level::verify(lev, slong)))
    return UL_FAIL; /* no solution?? */

  say(GREEN "Level and solution ok." POP);
  say("Optimizing...");

  solution * opt = optimize::opt(lev, slong);
  if (!opt) {
    say(RED "optimization failed" POP);
    return UL_FAIL;
  }
  extent<solution> es(opt);

  say(YELLOW + itos(slong->length) + GREY " " LRARROW " " POP +
      itos(opt->length) + POP);

  http * hh = client::connect(plr, tx, this);

  if (!hh) return UL_FAIL;

  string solcont = opt->tostring();

  formalist * fl = 0;

  /* XXX seems necessary! bug in aphasia cgi? */
  formalist::pusharg(fl, "dummy", "dummy");
  formalist::pusharg(fl, "id", itos(plr->webid));
  formalist::pusharg(fl, "seql", itos(plr->webseql));
  formalist::pusharg(fl, "seqh", itos(plr->webseqh));
  formalist::pusharg(fl, "text", text);
  formalist::pushfile(fl, "lev", "lev.esx", levcont);
  formalist::pushfile(fl, "sol", "sol.esx", solcont);

  redraw();

  string out;
  if (client::rpcput(hh, UPLOAD_RPC, fl, out)) {
    message::quick(this, GREEN "success!" POP,
		   "OK", "", PICS THUMBICON);
    formalist::diminish(fl);

    return UL_OK;
  } else {
    message::no(this, RED "upload failed: " + 
		out + POP);
    formalist::diminish(fl);

    return UL_FAIL;
  }

}

void ulreal::screenresize() {
  /* XXX resize */
}

void ulreal::draw() {
  sdlutil::clearsurface(screen, BGCOLOR);
  tx->draw();
}

upload::~upload() {}
