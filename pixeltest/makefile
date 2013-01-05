
default : smlversion.exe

SDLVERSION=1.2.15
SDLIMAGEVERSION=1.2.12
SDLNETVERSION=1.2.7
SDLMIXERVERSION=1.2.11

# Note the DLLs in the current directory are 32 bit, so if you change
# the architecture (I couldn't get it to work anyway), then you need to
# change the DLLs too. If the DLLs are the wrong architecture, it will
# immediately exit with no feedback.
# SDLARCH=x64
SDLARCH=x86

# Showing console output. The most important thing is setting the
# subsystem to "console", otherwise, no amount of redirection or
# defines or environment variables will work (I don't think this
# has anything to do with SDL in fact). 

# to use precompiled main function, no console
# LIBMAIN="SDL\lib\${SDLARCH}\SDLmain.lib"
# OBJMAIN=
# SUBSYSTEM=/subsystem:windows

# MLTON='c:\Program Files (x86)\MLton\bin\mlton' -target x86_64-w64-mingw32 -codegen amd64
MLTON=/c/mlton/bin/mlton.bat
# -target x86_64-w64-mingw32 -codegen amd64

MINGWGCC=/c/mlton/bin/gcc -std=c99 -O1 -fomit-frame-pointer -fno-strict-aliasing -w -fschedule-insns -fschedule-insns2 -malign-functions=5 -malign-jumps=2 -I SDL/include -I SDL_image/include -I/c/mlton/lib/mlton/include
# x86_64-w64-mingw32-gcc -m64

%.o : %.c makefile *.h
	${MINGWGCC} -c $< -o $@

%.o : ../sdlml/%.c makefile
	${MINGWGCC} -c -D WIN32 $< -o $@

sdl_win32_main.o : sdl_win32_main.c makefile
	${MINGWGCC} -D_GNU_SOURCE=1 -c $< -o $@

#  -ltiff -lpng -ljpeg -lz -lSDL_net
#  -link-opt "--enable-stdcall-fixup" -link-opt "--enable-stdcall-fixup" 

#  -mwindows works, disables console?
#  -Dmain=SDL_main
smlversion.exe : sdl_win32_main.o smlversion.o sdlml.o smlversion.cm smlversion.sml makefile
	${MLTON} @MLton max-heap 512m -- -keep g -keep o -verbose 1 -cc-opt " -I SDL/include -Dmain=SDL_main " -link-opt "-Wl,--subsystem,console -LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH} -lSDL -lSDL_image -lkernel32 -lmingw32" -output $@ -default-ann 'allowFFI true' smlversion.cm sdl_win32_main.o smlversion.o sdlml.o

clean :
	rm -f *.obj *.exe *.manifest *.ilk *.pdb *.o


# XXX delete

maintest.o : maintest.c
	${MINGWGCC} -c -Dmain=SDL_main $< -o $@

maintest.exe : sdl_win32_main.o smlversion.o maintest.o
	${MINGWGCC} -o $@ $^ -LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH}  -lSDL -lSDL_image 
