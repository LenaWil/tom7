
#include "http.h"
#include "extent.h"
#include "util.h"

#define DMSG if (log_message) (*log_message)

struct httpreal : public http {
  httpreal ();
  virtual ~httpreal();
  virtual void destroy ();
  virtual void setua(string);
  virtual bool connect(string host, int port = 80);
  virtual httpresult get(string path, string & out);
  virtual httpresult gettempfile(string path, string & file);
  virtual httpresult put(string path,
			 formalist * items,
			 string & out);

  virtual void setcallback(httpcallback * cb) {
    callback = cb;
  }

private:

  virtual FILE * tempfile(string & f);

  virtual string readrest();
  virtual string readresttofile();
  virtual string readn(int);
  virtual string readntofile(int);

  virtual httpresult req_general(string req, string & res, bool tofile);
  virtual httpresult get_general(string path, string & arg, bool tofile);
  virtual void bye() {
    if (conn) {
      SDLNet_TCP_Close(conn);
      conn = 0;
    }
  }

  httpcallback * callback;

  string ua;

  IPaddress remote;

  TCPsocket conn;

  /* for virtual servers */
  string host;

};

httpresult httpreal::get(string path, string & out_) {
  DMSG (util::ptos(this) + " get(" + path + ")\n");
  return get_general(path, out_, false);
}

httpresult httpreal::gettempfile(string path, string & out_) {
  DMSG (util::ptos(this) + " gettempfile(" + path + ")\n");
  return get_general(path, out_, true);
}

httpreal::httpreal () {
  callback = 0;
  conn = 0;
  remote.host = 0;
  remote.port = 0;
  log_message = 0;
}

httpreal::~httpreal () { }

void httpreal::destroy () {
  /* ? */
  if (conn) {
    DMSG (util::ptos(this) + " destroy\n");
    SDLNet_TCP_Close(conn);
    conn = 0;
  }
  delete this;
}

void httpreal::setua(string s) { ua = s; }

bool httpreal::connect(string chost, int port) {

  DMSG (util::ptos(this) + " connect '" + chost + "':" + itos(port) + "\n");
  
  /* should work for "snoot.org" or "128.2.194.11" */
  if(SDLNet_ResolveHost(&remote, (char *)chost.c_str(), port)) {
    DMSG (util::ptos(this) + " can't resolve: " + (string)(SDLNet_GetError()) + "\n");
    return false;
  }

  host = chost;

  DMSG (util::ptos(this) + " ok\n");

  return true;
}

void append(string & s, char * vec, unsigned int l) {
  unsigned int slen = s.length ();
  unsigned int nlen = l + slen;
  string ret(nlen, '*');

  for(unsigned int u = 0; u < slen; u ++) {
    ret[u] = s[u];

  }
  for(unsigned int v = 0; v < l; v ++) {
    ret[v + slen] = vec[v];
  }

  s = ret;
}

bool sendall(TCPsocket socket, string d) {
  int len = d.length();
  if (len != SDLNet_TCP_Send(socket, (void*)d.c_str(), len)) return false;
  else return true;
}

httpresult httpreal::put(string path,
			 formalist * items,
			 string & out) {

  /* large positive randomish number */
  int bnd = 0x10000000 | (0x7FFFFFFE & (util::random()));

  string boundary = "---------------------------" + itos(bnd);

  /* precompute body because we needs its length */
  string body = "--" + boundary;

  /* in loop, body ends with boundary ( no \r\n ) */
  while(items) {
    switch (items->ty) {
    case FT_ARG:
      body += "\r\nContent-Disposition: form-data; name=\"" + 
	items->name + "\"\r\n\r\n" +
	items->content;
      break;
    default:
    case FT_FILE:
      body += "\r\nContent-Disposition: form-data; name=\"" +
	items->name + "\"; filename=\"" +
	items->filename + "\"\r\n"
	"Content-Type: application/octet-stream\r\n\r\n" +
	items->content;
      break;
    }
    body += "\r\n--" + boundary;
    items = items -> next;
  }

  body += "--\r\n";

  int clen = body.length();

  /* XXX if I use http/1.1 here, result has some extra
     crap at the beginning */
  string hdr = 
    "POST " + path + " HTTP/1.0\r\n"
    "User-Agent: " + ua + "\r\n"
    "Host: " + host + "\r\n"
    "Accept: */*\r\n"
    //    "Connection: close\r\n"
    "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n"
    "Content-Length: " + itos(clen) + "\r\n"
    "\r\n";

  return req_general(hdr + body, out, false);

}


/*
  GET /abcd HTTP/1.0
  User-Agent: Wget/1.5.3
  Host: gs82.sp.cs.cmu.edu:8888
  Accept: * / * (together)
*/

httpresult httpreal::get_general(string path, string & res, bool tofile) {
  string req = 
    "GET " + path + " HTTP/1.0\r\n"
    "User-Agent: " + ua + "\r\n"
    "Host: " + host + "\r\n"
    "Accept: */*\r\n"
    "\r\n";
    
  return req_general(req, res, tofile);

}

httpresult httpreal::req_general(string req, string & res, bool tofile) {

  DMSG (util::ptos(this) + " conn@" + util::ptos(conn) + " req_general: \n[" + req + "]\n");

  /* we don't use keep-alive now. each request is a new
     connection. */
  bye();
  if (! (conn = SDLNet_TCP_Open(&remote))) {
    DMSG (util::ptos(this) + " can't connect: " + (string)(SDLNet_GetError()) + "\n");
    return HT_ERROR;
  }

  DMSG (util::ptos(this) + " connected.\n");
 
  if (!sendall(conn, req)) {
    /* error. try again? */
    DMSG (util::ptos(this) + " can't send: " + (string)(SDLNet_GetError()) + "\n");
    SDLNet_TCP_Close(conn);
    conn = 0;
    return HT_ERROR;
  }

  DMSG (util::ptos(this) + " sent request.\n");

  /* read headers. */
  string cline;
  char c;
  int first = 1;

  /* could save other headers, but this
     is the only one we really need. */
  int contentlen = -1;
  enum cty { CT_NONE, CT_CLOSE, CT_KEEP, };
  cty connecttype = CT_NONE;

  /* first will be true if this is the first line of the
     response. cline holds the partially completed line.

     unfortunately we must read single bytes at this point
     so that we don't accidentally move into the data area.
  */
  for(;;) {
    if (SDLNet_TCP_Recv(conn, &c, 1) != 1) {
      DMSG (util::ptos(this) + " can't recv: " + (string)(SDLNet_GetError()) + "\n");
      printf("Error in recv.\n");
      bye();
      return HT_ERROR;
    }

    {
      string ss = " ";
      ss[0] = c;
      DMSG((string)"[" + ss + "]");
    }

    if (c == '\r') continue;
    if (c == '\n') {
      /* process a line. */
      string line = cline;
      cline = "";

      if (first) {
	  
	/* HTTP/1.x */
	util::chop(line);
	/* 200 */
	string status = util::chop(line);
	    
	if (status != "200") {
	  /* XXX or whatever ... */
	  DMSG (util::ptos(this) + " got status code " + status + "\n");
	  /* close connection, since we don't want to read
	     anything. */
	  bye();
	  return HT_404;
	}
	first = 0;
      } else { /* not first line */
	if (line == "") {
	  /* empty line means read content! */
	  DMSG("++content mode++\n");
	  goto readcontent;
	} else { /* is a header line */

	  DMSG("header line [" + line + "]\n");

	  string field = util::chop(line);

	  /*
	    HTTP/1.1 200 OK
	    Date: Sun, 28 Sep 2003 21:07:49 GMT
	    Server: Apache/1.3.26 (Unix) mod_fastcgi/2.2.12
	    Last-Modified: Thu, 05 Dec 2002 15:22:12 GMT
	    ETag: "c784b-158-3def6f24"
	    Accept-Ranges: bytes
	    Content-Length: 344
	    Connection: close
	    Content-Type: text/html
		
	    (content)
	  */

	  if (field == "Content-Length:") {
	    string l = util::chop(line);
	    contentlen = atoi(l.c_str());
	    DMSG("content length is " + itos (contentlen) + "\n");
	  } else if (field == "Connection:") {
	    string how = util::lcase(util::chop(line));
	    if (how == "close") 
	      connecttype = CT_CLOSE;
	    else if (how == "keepalive")
	      connecttype = CT_KEEP;
	    else { 
	      /* bad header */
	      DMSG("bad connection type\n");
	      bye();
	      return HT_ERROR;
	    }
	  } else {
	    /* ignored */
	  }
	}

      }

    } else { /* c != \n */
      cline += c;
    }
  } /* for ever */

    /* expect contentlen > -1,
       or connection == CT_CLOSE. (checked)
       connection is in state ready to receive data.
    */
 readcontent:
    
  if (contentlen == -1) {
      
    if (connecttype != CT_CLOSE) {
      DMSG("content length but not close\n");
      bye();
      return HT_ERROR;
    }

    /* read until failure */

    if (tofile) {
      res = readresttofile();
      /* printf("rtof: %s\n", res.c_str()); */
      return HT_OK;
    } else {
      res = readrest();
      return HT_OK;
    }

  } else {
    /* have content length */

    if (tofile) {
      res = readntofile(contentlen);
      /* printf("ntof: %s\n", res.c_str()); */
      return HT_OK;
    } else {
      res = readn(contentlen);
      return HT_OK;
    }

  }
    
  /* XXX unreachable */
  return HT_ERROR;

}

#define BUFLEN 1024

/* XXX use util::tempfile */
FILE * httpreal::tempfile(string & f) {
  static int call = 0;
  int pid = util::getpid ();
  int tries = 256;
  call++;
  while(tries--) {
    char fname[256];
    sprintf(fname, "dl%d%04X%04X.deleteme", call, pid, 
	    (int)(0xFFFF & util::random()));

    FILE * ret = util::open_new(fname);
    if (ret) { 
      f = fname;
      return ret;
    }
  }
  return 0;
}

string httpreal::readresttofile() {
  string fname;
  FILE * ff = tempfile(fname);

  DMSG("reading to file ... not logged.\n");

  if (!ff) return "";

  /* printf("fname %s\n", fname.c_str()); */

  char buf[BUFLEN];

  int n = 0;

  int x;
  while((x = SDLNet_TCP_Recv(conn, buf, BUFLEN)) > 0) {
    fwrite(buf, 1, x, ff);
    if (callback) callback->progress(n += x, -1);
  }

  fclose(ff);

  SDLNet_TCP_Close(conn);
  conn = 0;

  return fname;
}

string httpreal::readrest() {
  string acc;

  char buf [BUFLEN];

  int x;

  int n = 0;

  DMSG("reading rest...\n");

  while((x = SDLNet_TCP_Recv(conn, buf, BUFLEN)) > 0) {
    append(acc, buf, x);
    if (callback) callback->progress(n += x, -1);
  }
  
  SDLNet_TCP_Close(conn);
  conn = 0;

  DMSG("contents\n[" + acc + "]\n");

  return acc;
}

string httpreal::readn(int n) {
  char * buf = new char[n];
  extentda<char> eb(buf);

  DMSG("reading " + itos(n) + "...\n");

  int total = n;
  int rem = n;
  int done = 0;
  int x;
  while (rem > 0) {
    x = SDLNet_TCP_Recv(conn, buf + done, rem);
    if (x <= 0) return "";

    done += x;
    rem -= x;
    if (callback) callback->progress(done, total);
  }
  
  string ret = "";
  append(ret, buf, n);

  DMSG("contents\n[" + ret + "]\n");

  return ret;
}

string httpreal::readntofile(int n) {

  int total = n;
  int rem = n;

  string fname;
  FILE * ff = tempfile(fname);
   
  if (!ff) return "";

  /* printf("fname %s\n", fname.c_str()); */

  char buf[BUFLEN];

  int done = 0;
  int x;
  while (rem > 0) {
    x = SDLNet_TCP_Recv(conn, buf, util::minimum(BUFLEN,rem));
    if (x <= 0) {
      fclose(ff);
      printf("bad exit from readntofile\n");
      return "";
    }

    fwrite(buf, 1, x, ff);

    rem -= x;
    if (callback) callback->progress(done += x, total);
  }
  
  fclose(ff);
  return fname;
}

/* export through http interface */
http * http::create() {
  return new httpreal();
}

/* XXX move to its own file? */
string httputil::urlencode(string s) {

  string out;
  for (unsigned x = 0; x < s.length(); x++) {
    if (s[x] == ' ')
      out += '+';
    else if ((s[x] >= 'a' && s[x] <= 'z')
         ||  (s[x] >= 'A' && s[x] <= 'Z') || s[x] == '.'
         ||  (s[x] >= '0' && s[x] <= '9')) {
      out += s[x];
    } else {
      out += '%';
      out += "0123456789ABCDEF"[15&(s[x]>>4)];
      out += "0123456789ABCDEF"[s[x]&15];
    }
  }
  return out;

}
