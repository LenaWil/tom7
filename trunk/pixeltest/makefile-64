
default : maintest.exe sdl_win32_main.o smlversion.o

DEBUGFLAGS = /Od /GZ /MDd /FD /D "_DEBUG"
FASTFLAGS = /MD /Ox /Oi /Oy /Ob2 /GL

# WHICHFLAGS = ${DEBUGFLAGS}
WHICHFLAGS = ${FASTFLAGS}

SDLVERSION=1.2.15
SDLIMAGEVERSION=1.2.12
SDLNETVERSION=1.2.7
SDLMIXERVERSION=1.2.11

SDLARCH=x64

#  /I "SDL_net-${SDLNETVERSION}\include" /I "SDL_mixer-${SDLMIXERVERSION}\include"

# /J is unsigned chars
COMPILE=cl /nologo ${WHICHFLAGS} /EHsc /W3 /I "..\cc-lib" /I "SDL\include" /I "SDL_image\include" /I "..\cc-lib" /D "WIN32" /D "_WINDOWS" /D "_MBCS" /D "COMPILER_MSVC" /J /c

# add these next: "SDL_net-${SDLNETVERSION}\lib\SDL_net.lib" "SDL_mixer-${SDLMIXERVERSION}\lib\SDL_mixer.lib"

BASICLIBS=shell32.lib
# libcpmt.lib msvcrt.lib msvcprt.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib uuid.lib
#  /nodefaultlib

# Showing console output. The most important thing is setting the
# subsystem to "console", otherwise, no amount of redirection or
# defines or environment variables will work (I don't think this
# has anything to do with SDL in fact). 

# to use precompiled main function, no console
# LIBMAIN="SDL\lib\${SDLARCH}\SDLmain.lib"
# OBJMAIN=
# SUBSYSTEM=/subsystem:windows

# to use custom one (shows stderr on console)
LIBMAIN=
OBJMAIN=sdl_win32_main.obj
SUBSYSTEM=/subsystem:console

# MLTON='c:\Program Files (x86)\MLton\bin\mlton' -target x86_64-w64-mingw32 -codegen amd64
MLTON='/c/Program Files (x86)/MLton/bin/mlton' -target x86_64-w64-mingw32 -codegen amd64

LINK=link /LTCG oldnames.lib ${LIBMAIN} "SDL\lib\${SDLARCH}\SDL.lib" "SDL_image\lib\${SDLARCH}\SDL_image.lib" ${BASICLIBS} /nologo ${SUBSYSTEM} /debug /machine:X64 /libpath:"SDL\lib\${SDLARCH}" /libpath:"SDL_image\lib\${SDLARCH}"

%.obj : ../cc-lib/%.cc
	${COMPILE} $<

%.obj : ../cc-lib/sdl/%.cc
	${COMPILE} $<

%.obj : %.cc
	${COMPILE} $<

%.obj : %.c
	${COMPILE} $<


# MINGWGCC=x86_64-w64-mingw32-gcc -std=c99 -m64 -O -I SDL/include -I SDL_image/include


#  %.o : ../cc-lib/%.cc
#  	${MINGWGCC} -c $< -o $@
#  
#  %.o : ../cc-lib/sdl/%.cc
#  	${MINGWGCC} -c $< -o $@

%.o : %.c
	${MINGWGCC} -c $< -o $@

sdl_win32_main.o : sdl_win32_main.c
	${MINGWGCC} -D_GNU_SOURCE=1 -c $< -o $@

pixeltest.exe : pixeltest.obj sdlutil.obj util.obj ${OBJMAIN}
	${LINK} /out:$@ $^
	rm -f *.manifest *.pdb

#  -cc-opt "-I/usr/local/include"
# XXX see "fixed"(er) version in compile.bat
smlversion.exe : sdl_win32_main.o smlversion.o
	${MLTON} @MLton max-heap 512m -- -cc-opt "-g -Dmain=SDL_main" -link-opt "--enable-stdcall-fixup" -link-opt "--enable-stdcall-fixup" -link-opt "-LSDL\lib\{$SDLARCH} -LSDL_image\lib\${SDLARCH} -lmingw32 -lSDL -mwindows -lSDL_image -ltiff -lpng -ljpeg -lz -lSDL_net -lkernel32" -output $@ -default-ann 'allowFFI true' smlversion.cm $^

maintest.o : maintest.c
	${MINGWGCC} -c -Dmain=SDL_main $< -o $@

maintest.exe: sdl_win32_main.o smlversion.o maintest.o
	${MINGWGCC} -o maintest.exe --enable-stdcall-fixup -LSDL/lib/x64 -LSDL_image/lib/x64 -advapi32 -lshell32 -luser32 -lkernel32 -lmingw32 -lgcc -lmoldname -lmingwex -lmsvcrt -lSDL -lSDLmain  -m64 -lSDL_image sdl_win32_main.o smlversion.o maintest.o

clean :
	rm -f *.obj *.exe *.manifest *.ilk *.pdb *.o
