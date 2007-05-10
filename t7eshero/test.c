
#if 0
#include <SDL.h>


int ml_test() {
  if (SDL_Init (SDL_INIT_VIDEO | 
                SDL_INIT_TIMER | 
		SDL_INIT_AUDIO) < 0) {
							
    return 0;
  } else return 1;
}

extern int win32init();

int uuuzzz (int argc, char ** argv) {
  win32init();

  ml_test();
  printf("ok!");
}
#endif

int main() {
  printf("ok!\n");
  return 0;
}
