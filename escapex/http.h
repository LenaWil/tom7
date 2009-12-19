
/* maximally simple interface to HTTP
   using SDL_net */

#ifndef __HTTP_H
#define __HTTP_H

#include "SDL.h"
#include "SDL_image.h"
#include "SDL_net.h"
#include <math.h>

#include <string>
using namespace std;

#include "httputil.h"

/* Before using the http class, you must initialize SDL_net
   with SDLNet_Init(). */

/* results from GET/POST/etc. */
enum httpresult {
  HT_OK, HT_404, HT_ERROR,
};

/* XXX allow return codes that cancel download */
struct httpcallback {
  /* in bytes. total will be -1 if unknown. */
  virtual void progress(int recvd, int total) = 0;
};

/* interface only */
struct http {
  
  static http * create ();
  virtual void destroy () = 0;

  /* set user-agent */
  virtual void setua(string) = 0;
  /* ... other stuff ... */

  /* doesn't really connect -- just sets host:port for
     later requests. might fail if can't look up hostname. */
  virtual bool connect(string host, int port = 80) = 0;

  /* download the entire thing to a string */
  virtual httpresult get(string path, string & out) = 0;
  
  /* create a temp file (in the cwd) and download to that.
     return the name of the temp file */
  virtual httpresult gettempfile(string path, string & file) = 0;

  /* use post, allowing to upload files */
  virtual httpresult put(string path,
			 formalist * items,
			 string & out) = 0;

  /* set callback object. This object is never freed. */
  virtual void setcallback(httpcallback *) = 0;

  /* this will be called with various debugging
     messages, if non-null */
  void (*log_message)(const string & s);

  virtual ~http() {};
};


#endif
