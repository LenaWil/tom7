
#include "escapex.h"

/* XXX put this stuff in escapex.cc? */
SDL_Surface * screen;

/* XXX should be bools */
int network;
int audio;


bool handle_video_event(drawable *parent, const SDL_Event &event) {
  switch(event.type) {
  case SDL_VIDEORESIZE: {
    SDL_ResizeEvent * re = (SDL_ResizeEvent*)&event;
    screen = sdlutil::makescreen(re->w, re->h);
    if (parent) {
      parent->screenresize();
      parent->draw();
      SDL_Flip(screen);
    }
    return true;
  }
  case SDL_VIDEOEXPOSE:
    if (parent) {
      parent->draw();
      SDL_Flip(screen);
    }
    return true;
  default:
    return false;
  }
}
