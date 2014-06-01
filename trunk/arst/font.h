
#ifndef __FONT_H
#define __FONT_H

#include "SDL.h"
#include <string>

using namespace std;

/* XXX move some of this to fontutil */
struct Font {

  int width, height, styles, overlap;

  static Font * create(SDL_Surface *screen,
                       string file,
                       string charmap,
                       int width,
                       int height,
                       int styles=1,
                       int overlap=0,
                       int dims=2);

  // Takes ownership of the font surface.
  static Font * create_from_surface(SDL_Surface *screen,
                                    SDL_Surface *font_surface,
                                    string charmap,
                                    int width,
                                    int height,
                                    int styles=1,
                                    int overlap=0,
                                    int dims=2);

  /* number of drawn characters, ignoring control codes.
     length(s) * (width-overlap) gives
     the screen width. */
  static unsigned int length(string);
  static string substr(const string & s,
                       unsigned int start,
                       unsigned int len);
  /* len must be <= font::length(s) */
  static string prefix(const string & s,
                       unsigned int len);
  static string suffix(const string & s,
                       unsigned int len);

  /* similarly, pad a string out to n displayable
     characters, doing the right thing for
     color codes. If n is negative, pad with spaces
     on the left side instead of right.

     precondition: |n| >= 3 */
  static string pad(const string & s, int n);

  /* truncate to n chars if too long; if n is
     negative, truncate off the left side instead of
     the right. */
  static string truncate(const string & s, int n);


  /* return the size in pixels of the string.
     this ignores formatting characters.
     sizey is always font.height.
  */
  virtual int sizex(const string &) = 0;
  virtual int sizex_plain(const string &) = 0;

  /* returns the number of lines in the string,
     which is always at least 1 unless the
     string is empty. */
  static int lines(const string &);

  /* specify the top-left pixel. */
  virtual void draw(int x, int y, string s) = 0;
  virtual void draw_plain(int x, int y, string s) = 0;
  virtual void drawto(SDL_Surface *, int x, int y, string s) = 0;
  virtual void drawto_plain(SDL_Surface *, int x, int y, string s) = 0;

  /* draw a multi-line string.
     the height in pixels of the area drawn is returned. */
  virtual int drawlines(int x, int y, string s) = 0;

  /* same, but centers each line horizontally about the x position */
  virtual int drawcenter(int x, int y, string s) = 0;

  virtual void destroy() = 0;
  virtual ~Font();
};

#endif
