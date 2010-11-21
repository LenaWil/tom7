
# for mingw.

default : bddtest.exe

sdlml.o : ../sdlml/sdlml.c
	gcc -O -I /usr/local/include `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlml.c -o sdlml.o

sdlmix.o: ../sdlml/sdlmix.c
	gcc -O `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlmix.c -o sdlmix.o

# -const 'Exn.keepHistory true'
bddtest.exe : sdlml.o *.sml bddtest.cm messagebox_fake.o sdlmix.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml
	mlton @MLton max-heap 200m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -lSDL_mixer -ltiff -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' bddtest.cm sdlml.o sdlmix.o messagebox_fake.o
