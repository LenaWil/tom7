
# for mingw.

# animate.exe
# bddtest.exe
# makebody.exe
default : makebody.exe

sdlml.o : ../sdlml/sdlml.c
	gcc -O -I /usr/local/include `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlml.c -o sdlml.o

sdlmix.o: ../sdlml/sdlmix.c
	gcc -O `/usr/local/bin/sdl-config --cflags` -c ../sdlml/sdlmix.c -o sdlmix.o

pngsave.o : ../sdlml/pngsave.c
	gcc -O -I /usr/local/include `/usr/local/bin/sdl-config --cflags` -c ../sdlml/pngsave.c -o pngsave.o

SMLS = prelude.sml images.sml real32.sml letter.sml maths.sml

# -const 'Exn.keepHistory true'
makebody.exe : sdlml.o pngsave.o makebody.sml editing.sml ${SMLS} makebody.cm messagebox_fake.o sdlmix.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml ../sml-lib/data/*.sml ../sml-lib/util/*.sml
	mlton @MLton max-heap 200m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -lSDL_mixer -ltiff -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' makebody.cm sdlml.o sdlmix.o pngsave.o messagebox_fake.o

animate.exe : sdlml.o pngsave.o animate.sml ${SMLS} animate.cm messagebox_fake.o sdlmix.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml ../sml-lib/data/*.sml ../sml-lib/util/*.sml
	mlton @MLton max-heap 200m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "`/usr/local/bin/sdl-config --libs` -lSDL_image -lSDL_mixer -ltiff -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' animate.cm sdlml.o sdlmix.o pngsave.o messagebox_fake.o

clean :
	rm -f *.o *.exe

CPPFLAGS = -O -I .
CXXFLAGS = -O -I .
