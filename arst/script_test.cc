
#include "script.h"
#include "SDL.h"

int SDL_main(int argc, char *argv[]) {
  Script *s = Script::FromString
    ("0 hello\n"
     "40 in\n"
     "50 a\n"
     "66 galaxy\n"
     "77 far\n");
  
  s->DebugPrint();
  delete s;
  return 0;
}
