
# for mingw.

default : mididance.exe
#  makewaypoints.exe
# autodance.exe

sdlml.o : ../sdlml/sdlml.c
	gcc -O -I /usr/local/include `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlml.c -o sdlml.o

pngsave.o : ../sdlml/pngsave.c
	gcc -O -I /usr/local/include `/usr/local/bin/sdl-config --cflags` -c ../sdlml/pngsave.c -o pngsave.o

SMLS = frameutil.sml framecache*.sml waypoints*.sml

# -const 'Exn.keepHistory true'
autodance.exe : sdlml.o pngsave.o autodance.sml ${SMLS} autodance.cm makefile ../sdlml/*.sml ../sdlml/*.c
	mlton @MLton max-heap 200m -- -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -ltiff -lpng -ljpeg -lz -lmad" -output $@ -default-ann 'allowFFI true' autodance.cm sdlml.o pngsave.o

makewaypoints.exe : sdlml.o pngsave.o makewaypoints.sml ${SMLS} makewaypoints.cm makefile ../sdlml/*.sml ../sdlml/*.c
	mlton @MLton max-heap 200m -- -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -ltiff -lpng -ljpeg -lz -lmad" -output $@ -default-ann 'allowFFI true' makewaypoints.cm sdlml.o pngsave.o

mididance.exe : sdlml.o pngsave.o mididance.sml ${SMLS} mididance.cm makefile ../sdlml/*.sml ../sdlml/*.c
	mlton @MLton max-heap 200m -- -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -ltiff -lpng -ljpeg -lz -lmad" -output $@ -default-ann 'allowFFI true' mididance.cm sdlml.o pngsave.o

clean :
	rm -f *.o *.exe ${OFILES}


# mogrify -format jpg midi*.png