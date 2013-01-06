
# for mingw.

# animate.exe
# bddtest.exe
# makebody.exe
default : makebody.exe

SDLARCH=x86
MLTON=/c/mlton/bin/mlton.bat
MINGWGCC=/c/mlton/bin/gcc -std=c99 -O1 -fomit-frame-pointer -fno-strict-aliasing -w -fschedule-insns -fschedule-insns2 -malign-functions=5 -malign-jumps=2 -I SDL/include -I SDL_image/include -I/c/mlton/lib/mlton/include

%.o : ../sdlml/%.c
	${MINGWGCC} -c $< -DWIN32 -o $@

%.o : %.c
	${MINGWGCC} -c $< -o $@

SMLS = prelude.sml images.sml real32.sml letter.sml maths.sml

# sdlmix.o

# -const 'Exn.keepHistory true'
makebody.exe : sdlml.o pngsave.o makebody.sml editing.sml ${SMLS} makebody.cm messagebox_fake.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml ../sml-lib/data/*.sml ../sml-lib/util/*.sml
	${MLTON} @MLton max-heap 500m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "-LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH} -lSDL -lSDL_image -ltiff-5 -lpng15-15 -ljpeg-8 -lzlib1" -output $@ -default-ann 'allowFFI true' makebody.cm sdlml.o pngsave.o messagebox_fake.o

animate.exe : sdlml.o pngsave.o animate.sml ${SMLS} animate.cm messagebox_fake.o makefile ../sdlml/*.sml ../sdlml/*.c ../sml-lib/bdd/*.sml ../sml-lib/data/*.sml ../sml-lib/util/*.sml
	${MLTON} @MLton max-heap 500m -- -const 'Exn.keepHistory true' -default-ann 'warnUnused true' -default-ann 'sequenceNonUnit warn' -cc-opt "-I/usr/local/include" -link-opt "-LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH} -lSDL -lSDL_image -lpng -ljpeg -lz -lmad -lvorbisfile -lvorbis -logg" -output $@ -default-ann 'allowFFI true' animate.cm sdlml.o pngsave.o messagebox_fake.o

clean :
	rm -f *.o *.exe
