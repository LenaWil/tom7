
#include <SDL.h>

int SDL_main(int x, char ** argv) {
  if (SDL_Init (SDL_INIT_VIDEO | 
                SDL_INIT_TIMER | 
		SDL_INIT_AUDIO) < 0) {
							
    return 0;
  } else return 1;
}
