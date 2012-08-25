
#include <stdio.h>

#define TILEWIDTH 26
#define TILEHEIGHT 26
#define TILESW 16
#define TILESH 12

#define WORLDTILES 384

#define SCREENWIDTH (TILEWIDTH * TILESW)
#define SCREENHEIGHT (TILEHEIGHT * TILESH)

int main () {

  printf("default :");
  for (int screeny = 0; screeny < (WORLDTILES / TILESH); screeny++) {
    for (int screenx = 0; screenx < (WORLDTILES / TILESW); screenx++) {
      printf(" screen_%d_%d.png", screenx, screeny);
    }
  }
  printf("\n\n");

  for (int screeny = 0; screeny < (WORLDTILES / TILESH); screeny++) {
    for (int screenx = 0; screenx < (WORLDTILES / TILESW); screenx++) {
      printf("screen_%d_%d.png : ../wholemap.bmp\n"
	     "\t/bin/convert ../wholemap.bmp -crop %dx%d+%d+%d\\! "
	     "-layers merge $@\n\n",
	     screenx, screeny,
	     SCREENWIDTH, SCREENHEIGHT,
	     SCREENWIDTH * screenx, SCREENHEIGHT * screeny);
    }
  }

  return 0;
}
