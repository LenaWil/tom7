#include <SDL.h>
#include <SDL_image.h>
#include <windows.h>

int main(int argc, char ** argv) {

  MessageBoxA (0, "hello", "ok", 0);

  if (SDL_Init (SDL_INIT_VIDEO | 
                SDL_INIT_TIMER | 
		/* for debugging */
		SDL_INIT_NOPARACHUTE |
		SDL_INIT_AUDIO) < 0) {

    char msg[512];
    sprintf(msg, "Unable to initialize SDL. (%s)\n", SDL_GetError());
    
    MessageBoxA(0, msg, "uh", 0);
    
    return 0;
  }

  /* SDL_DOUBLEBUF only valid with SDL_HWSURFACE! */
  SDL_Surface * screen = SDL_SetVideoMode(640, 480, 32,
					  SDL_SWSURFACE |
					  SDL_RESIZABLE);

  if (!screen) {
    MessageBoxA (0, "no screen", "ok", 0);
    return 0;
  }

  // MessageBoxA (0, "screen set", "ok", 0);

  SDL_Surface * png = IMG_Load("zapotec.bmp");

  if (!png) {
    MessageBoxA (0, "no png", "ok", 0);
    return 0;
  }

  { 
    SDL_Rect r;
    r.x = 10;
    r.y = 10;
    SDL_BlitSurface(png, 0, screen, &r);
  }

  SDL_Flip(screen);

  for(;;);

}
