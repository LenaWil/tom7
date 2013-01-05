
default : pixeltest.exe

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

LINK=link /LTCG oldnames.lib ${LIBMAIN} "SDL\lib\${SDLARCH}\SDL.lib" "SDL_image\lib\${SDLARCH}\SDL_image.lib" ${BASICLIBS} /nologo ${SUBSYSTEM} /debug /machine:X64 /libpath:"SDL\lib\${SDLARCH}" /libpath:"SDL_image\lib\${SDLARCH}"

%.obj : ../cc-lib/%.cc
	${COMPILE} $<

%.obj : ../cc-lib/sdl/%.cc
	${COMPILE} $<

%.obj : %.cc
	${COMPILE} $<

pixeltest.exe : pixeltest.obj sdlutil.obj util.obj ${OBJMAIN}
	${LINK} /out:$@ $^
	rm -f *.manifest *.pdb

clean :
	rm -f *.obj *.exe *.manifest *.ilk *.pdb
