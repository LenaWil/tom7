
#ifndef __CLIENT_H
#define __CLIENT_H

#include "drawable.h"
#include "textscroll.h"
#include "http.h"
#include "chars.h"
#include "message.h"
#include "extent.h"
#include "util.h"
#include "player.h"
#include "prefs.h"
#include "draw.h"

#define SUPERUSER (1)

#define PING_RPC "/f/a/escape/ping"
#define COMMENT_RPC "/f/a/escape/comment"
#define RATE_RPC "/f/a/escape/rate"
#define REGISTER_RPC "/f/a/escape/register"
#define UPLOAD_RPC "/f/a/escape/upload"
#define UPLOADSOL_RPC "/f/a/escape/upsol"
#define DELETE_RPC "/f/a/escape/deletefromgame"

#define HTTP_DEBUGFILE "netdebug.txt"

struct client {
  static http * connect(player * plr, textscroll * tx, drawable * that) {
    http * hh = http::create();

    if (prefs::getbool(plr, PREF_DEBUG_NET)) 
      hh->log_message = debug_log_message;

    string serveraddress = prefs::getstring(plr, PREF_SERVER);
    int serverport =
      (prefs::getbool(plr, PREF_ALTCONNECT))?8888:80;

    if (!hh) { 
      if (tx) tx->say(YELLOW "Couldn't create http object.");
      message::quick(that, "Upgrade failed!", "Cancel", "");
      return 0;
    }

    extent<http> eh(hh);

    string ua = "Escape (" VERSION "; " PLATFORM ")";
    if (tx) tx->say((string)"This is: " + ua);
  
    hh->setua(ua);

    if (tx) tx->say((string)
		    "Connecting to " YELLOW + serveraddress + 
		    WHITE":"POP + itos(serverport) + POP "...");

    if (that) {
      that->draw();
      SDL_Flip(screen);
    }

    if (!hh->connect(serveraddress, serverport)) {
      if (tx) tx->say((string)RED "Couldn't connect to " 
		      YELLOW + serveraddress + POP ".");
      message::quick(that, "Can't connect!", "Cancel", "");
      return 0;
    }

    eh.release();
    return hh;
  }

  /* XX add bool quiet=true; when false show progress */
  static bool quick_rpc(player *, string path, string query, string & ret);

  /* true on success */
  static bool rpc(http * hh, string path, string query, string & ret) {
    string m;
    httpresult hr = hh->get(path + (string)"?" + query, m);
    
    if (hr == HT_OK) {
      
      if (m.length () >= 2 &&
          m[0] == 'o' &&
          m[1] == 'k') {

	/* drop first token */
        (void) util::chop(m);
        ret = util::losewhitel(m);
        return true;
      } else { 
        ret = m;
        return false;
      }
    } else {
      ret = ("http request failed");
      return false;
    }

  }

  static bool rpcput(http * hh, string path, formalist * fl, string & ret) {
    string m;
    httpresult hr = hh->put(path, fl, m);
    
    if (hr == HT_OK) {
      
      if (m.length () >= 2 &&
          m[0] == 'o' &&
          m[1] == 'k') {

	/* drop first token */
        (void) util::chop(m);
        ret = util::losewhitel(m);
        return true;
      } else { 
        ret = m;
        return false;
      }
      
    } else if (hr == HT_404) {
      
      ret = "error code 404";
      return false;
    } else {
      ret = "error code (general)";
      return false;
    }
  }

  static void debug_log_message(const string & s) {
    FILE * f = fopen(HTTP_DEBUGFILE, "a");

    if (f) {
      fprintf(f, "%s", s.c_str());
      fclose(f);
    }
  }

  /* need the drawable to draw background, too */
  /* static */ struct quick_txdraw : public drawable {
    textscroll * tx;
    quick_txdraw() {
      tx = textscroll::create(fon);
      tx->posx = 5;
      tx->posy = 5;
      tx->width = screen->w - 10;
      tx->height = screen->h - 10;
    }

    void say(string s) { tx->say(s); }
    void draw() {
      sdlutil::clearsurface(screen, BGCOLOR);
      tx->draw();
    }
    void screenresize() {
      tx->screenresize();
    }

    virtual ~quick_txdraw() {
      tx->destroy();
    }
  };
  
};

#endif
