
default : smlversion.exe

SDLVERSION=1.2.15
SDLIMAGEVERSION=1.2.12
SDLNETVERSION=1.2.7
SDLMIXERVERSION=1.2.11

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

MINGWGCC=/c/mlton/bin/gcc -std=c99 -O1 -I SDL/include -I SDL_image/include -I/c/mlton/lib/mlton/include
# x86_64-w64-mingw32-gcc -m64

%.o : %.c makefile
	${MINGWGCC} -c $< -o $@

sdl_win32_main.o : sdl_win32_main.c makefile
	${MINGWGCC} -D_GNU_SOURCE=1 -c $< -o $@

#  -ltiff -lpng -ljpeg -lz -lSDL_net
#  -link-opt "--enable-stdcall-fixup" -link-opt "--enable-stdcall-fixup" 

#  -mwindows works, disables console?
#  -Dmain=SDL_main
smlversion.exe : sdl_win32_main.o smlversion.o decoymain.o smlversion.cm smlversion.sml makefile
	${MLTON} @MLton max-heap 512m -- -keep g -keep o -verbose 1 -cc-opt " -I SDL/include " -link-opt "-Wl,--subsystem,console -LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH} -lSDL -lSDL_image -lkernel32 -lmingw32" -output $@ -default-ann 'allowFFI true' smlversion.cm sdl_win32_main.o smlversion.o decoymain.o empty.o

anything.exe : smlversion.o empty.o smlversion.cm smlversion.sml makefile
	${MLTON} @MLton max-heap 512m -- -keep g -keep o -verbose 1 -link-opt " -LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH} -lSDL -lSDL_image -lkernel32 -lmingw32" -output $@ -default-ann 'allowFFI true' smlversion.cm empty.o smlversion.o


clean :
	rm -f *.obj *.exe *.manifest *.ilk *.pdb *.o


# XXX delete

maintest.o : maintest.c
	${MINGWGCC} -c -Dmain=SDL_main $< -o $@

maintest.exe : sdl_win32_main.o smlversion.o maintest.o
	${MINGWGCC} -o $@ $^ -LSDL/lib/${SDLARCH} -LSDL_image/lib/${SDLARCH}  -lSDL -lSDL_image 
