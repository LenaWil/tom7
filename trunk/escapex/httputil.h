
#ifndef __HTTPUTIL_H
#define __HTTPUTIL_H

#include <string>

struct httputil {
  static string urlencode(string);
};

enum formtype { FT_ARG, FT_FILE, };

struct formalist {
  formtype ty;
  string name;
  string filename;
  string content;
  formalist * next;

  static void pusharg(formalist *& l, string name, string arg) {
    formalist * x = new formalist;
    x->next = l;
    x->ty = FT_ARG;
    x->name = name;
    /* this appears to be too many */
    x->content = arg; // httputil::urlencode(arg);
    l = x;
  }

  static void pushfile(formalist *& l, string name, 
		       string filename, string contents) {
    formalist * x = new formalist;
    x->next = l;
    x->ty = FT_FILE;
    x->name = name;
    x->filename = filename;
    x->content = contents;
    l = x;
  }

  /* ie, destroy */
  static void diminish(formalist *& sl) {
    while (sl) {
      formalist * tmp = sl;
      sl = sl->next;
      delete tmp;
    }
  }

};


#endif
