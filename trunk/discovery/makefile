
# n.b. probably hard to build. needs mingw and SDL stuff in the path.
# see escape source for original.

default : packpng.exe

CPPFLAGS = -DNOSOUND=1 `sdl-config --cflags` 
CXXFLAGS = -g -Wall -O ${PROF} 



PROF =
LDFLAGS = -Wl,-rpath=.
LDLIBS = -lSDL_image -lSDL_net  `sdl-config --libs` -ltiff -lpng -ljpeg -lz

PNGHEADERS = -I /usr/local/include

%-console.o : %.cc
	g++ ${CXXFLAGS} ${CPPFLAGS} -DNOSOUND=1 -DUSE_DISPLAY_FORMAT=0 ${PNGHEADERS} $^ -c -o $@

packpng.exe : util-console.o sdlutil-console.o packpng-console.o pngsave-console.o winmain-console.o
	g++ -o $@ ${LDFLAGS} $^ ${LDLIBS}


clean :
	rm -f *.o packpng.exe
