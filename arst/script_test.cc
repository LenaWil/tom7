
#include "script.h"
#include "SDL.h"

int SDL_main(int argc, char *argv[]) {
  Script *s = Script::FromString
    (100,
     "0 hello\n"
     "39 ago\n"
     "40 in\n"
     "50 a\n"
     "66 galaxy\n"
     "77 far\n"
     "78 far\n"
     "79 away\n");
  
  s->DebugPrint();

  for (int i = 0; i < 100; i++) {
    Line *l = s->GetLine(i);
    printf("%d --> %d %s\n",
	   i, l->sample, l->s.c_str());
  }

  delete s;
  return 0;
}
