
# Try to detect OS. Assumes windows if nothing works, so you 
# may need to "export LINUX" or "export OSX" before you type make.

ifndef MINGW
ifndef LINUX
ifndef OSX
# makefile for windows. Windows is weird.

# On windows I have switched to mingw (export MINGW=true; see below),
# so Visual C++ may stop working as it drifts out of date, sorry.

SDLVERSION=1.2.11

# normally use these
ZLIBDIR = ..\SDL_image_1.2.4\lib
ZINCDIR = ..\SDL_image_1.2.4\include
PLIBDIR = ZLIBDIR
PINCDIR = ZINCDIR

# Or maybe these if you compile zlib and libpng yourself
# ZLIBDIR = ..\zlib
# ZINCDIR = ..\zlib
# PLIBDIR = ..\libpng
# PINCDIR = ..\libpng

# not sure what fd does
DEBUGFLAGS = /Od /GZ /MDd /FD /D "_DEBUG"
FASTFLAGS = /MD /Gf /G6 /O2 /Og /Oi /Oy /Ob2 /GL

WHICHFLAGS = ${DEBUGFLAGS}

default : escape.exe replace.exe

COMPILE=cl /nologo ${WHICHFLAGS} /W3 /GX /I "..\SDL-${SDLVERSION}\include" /I "..\SDL_image-1.2.4\include" /I "..\SDL_net-1.2.5\include" /I "..\SDL_mixer-1.2.6\include" /D "WIN32" /D "_WINDOWS" /D "_MBCS" /c /I ${ZINCDIR} /I ${PINCDIR}

COMPILECMDLINE=cl /nologo /MDd /W3 /GX /Od /I "..\SDL-${SDLVERSION}\include" /I "..\SDL_image-1.2.4\include" /I "..\SDL_net-1.2.5\include" /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /FD /GZ /c /I "..\libpng" /D "_CONSOLE"  /I ${ZINCDIR} /I ${PINCDIR}


# don't need?
# most recently..
# odbc32.lib odbccp32.lib
# probably could remove more, haven't tried... (does it even matter?)

LINK=link oldnames.lib "..\SDL-${SDLVERSION}\lib\SDL.lib" "..\SDL_image-1.2.4\lib\SDL_image.lib" "..\SDL_net-1.2.5\lib\SDL_net.lib" "..\SDL_mixer-1.2.6\lib\SDL_mixer.lib" libcpmt.lib msvcrt.lib msvcprt.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib uuid.lib /nologo /subsystem:windows /pdb:none /debug /machine:I386 /nodefaultlib /libpath:"..\SDL-${SDLVERSION}\lib" /libpath:"..\SDL_net-1.2.5\lib" /libpath:"..\SDL_mixer-1.2.6\lib"  /libpath:"..\SDL_image-1.2.4\lib" /libpath:${ZLIBDIR} /libpath:${PLIBDIR}

# for command line apps. no need for net or mixer.
LINKCMDLINE=link oldnames.lib "..\SDL-${SDLVERSION}\lib\SDL.lib" "..\SDL_image-1.2.4\lib\SDL_image.lib" libcpmt.lib msvcrt.lib msvcprt.lib kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib uuid.lib /nologo /subsystem:console /pdb:none /debug /machine:I386 /nodefaultlib /libpath:"..\SDL-${SDLVERSION}\lib" /libpath:"..\SDL_image-1.2.4\lib"  /libpath:${ZLIBDIR} /libpath:${PLIBDIR}

.dummy :

version : .dummy
	cl /nologo /D "WIN32" /GX version.cc
	./version.exe
	make clean
	make default

wc :
	wc -l *.cc *.h

RELEASEFILES=escape.exe replace.exe font.png fontsmall.png tiles.png tileutil.png title.png icon.png escape.txt SDL.dll SDL_image.dll SDL_net.dll jpeg.dll libpng13.dll zlib1.dll COPYING changelog animation.png SDL_mixer.dll splash.png

zip : .dummy ${RELEASEFILES}
	rm -rf escape-beta
	mkdir escape-beta
	cp -a triage escape-beta
	cp -a ${RELEASEFILES} escape-beta
	mkdir escape-beta/mylevels
	cp -a official escape-beta
	rm -rf escape-beta/official/CVS escape-beta/triage/CVS
	rm -rf escape-beta/official/.svn escape-beta/triage/.svn
	cp mylevels/index.esi escape-beta/mylevels/
	rm -f escape-beta.zip
	echo "=============================="
	echo "now zip escape-beta to release"
	echo "escape-beta.zip is already gone"
	echo "then do make zipup"
	echo "=============================="

releasefiles.win32 : makefile
	echo ${RELEASEFILES} > releasefiles.win32

escapesetup.exe : .dummy ${RELEASEFILES} escape.nsi
	makensis escape.nsi

installer : escapesetup.exe

zipup : escape-beta.zip
	pscp escape-beta.zip root@spacebar.org:/var/www/escape/

installerup : escapesetup.exe
	pscp escapesetup.exe root@spacebar.org:/var/www/escape/

# some rules for making objects, etc.

# how to compile object files
%.obj : %.cc selector.h extent.h
	${COMPILE} $<

animation_load.h animation.png animation_decs.h animation_defs.h : animation.pack
	rm -f animation_load.h animation.png animation_decs.h animation_defs.h
	make packpng.exe
	packpng.exe animation.pack animation
	rm -f animation.better
	pngcrush -e .better animation.png
	rm -f animation.png
	mv animation.better animation.png

sound_load.h : sound.pack packsound.cc
	make packsound.exe
	packsound.exe sound.pack sound

sound.obj : sound.cc sound_load.h sound.h
	${COMPILE} $<

level.obj : level.cc move.h
	${COMPILE} $<

animation.obj : animation.cc animation.h animation_load.h animation_decs.h animation_defs.h sound_load.h
	${COMPILE} $<

# it has to be different for the console =(
%-console.obj : %.cc
	${COMPILECMDLINE} $^ /Fo$@

sdlutil-console.obj : sdlutil.cc
	${COMPILECMDLINE} -DUSE_DISPLAY_FORMAT=0 $^ /Fo$@

escape.res : escape.rc escape.ico
	rc /r /fo escape.res escape.rc

escape.exe : main.obj level.obj sdlutil.obj play.obj font.obj dirent.obj load.obj util.obj md5.obj player.obj playerdb.obj prompt.obj draw.obj drawable.obj edit.obj editai.obj editprefab.obj mainmenu.obj upgrade.obj http.obj textscroll.obj message.obj update.obj dircache.obj upper.obj registration.obj upload.obj rating.obj menu.obj prefs.obj escape.res chunks.obj dirindex.obj textbox.obj analysis.obj generator.obj prime.obj commenting.obj cleanup.obj mainshow.obj handhold.obj animation.obj dirt.obj sound.obj base64.obj winmain.obj optimize.obj smanage.obj client.obj progress.obj leveldb.obj startup.obj
	${LINK} /out:"escape.exe" $^

# other executables that need to be built:

replace.exe : replace-console.obj util-console.obj
	${LINKCMDLINE} /out:$@ $^ user32.lib

convert.exe : convert-console.obj level-console.obj util-console.obj dirent-console.obj
	${LINKCMDLINE} /out:$@ $^

packpng.exe : util-console.obj font-console.obj level-console.obj sdlutil-console.obj packpng-console.obj pngsave-console.obj winmain-console.obj
	${LINKCMDLINE} /out:$@ $^ libpng13.lib

packsound.exe : util-console.obj packsound-console.obj winmain-console.obj
	${LINKCMDLINE} /out:$@ $^

mkupgrade.exe : mkupgrade-console.obj md5-console.obj
	${LINKCMDLINE} /out:$@ $^

UPGRADE : .dummy mkupgrade.exe releasefiles.win32 deletefiles.win32 symlinks.win32
	./mkupgrade.exe releasefiles.win32 symlinks.win32 deletefiles.win32 > UPGRADE

CURRENT : .dummy mkupgrade.exe
	./mkupgrade.exe -v > CURRENT

release : UPGRADE CURRENT
	pscp -C ${RELEASEFILES} UPGRADE CURRENT root@spacebar.org:/var/www/escape/win32/
	rm -f UPGRADE CURRENT mkupgrade.exe

clean :
	rm -f *.obj convert.exe escape.exe *.tmp *.delme *.pdb *.ilk *.o *.idb *.plg *.opt replace.exe *.ncb *.aps packpng.exe screenshot.exe replace.exe mkupgrade.exe version.exe
	touch mv_is_dumb~
	touch .\#mv_is_dumb
	mv -f *~ .\#* attic

# end windows makefile
endif
endif
endif


# -------------------------------------------------------------------

ifdef LINUX
# makefile for linux

OFILES = main.o level.o sdlutil.o load.o font.o play.o util.o md5.o player.o playerdb.o prompt.o draw.o drawable.o edit.o editprefab.o mainmenu.o upgrade.o http.o textscroll.o message.o update.o editai.o dircache.o upper.o registration.o upload.o rating.o menu.o prefs.o chunks.o dirindex.o textbox.o analysis.o generator.o prime.o commenting.o cleanup.o mainshow.o handhold.o animation.o dirt.o sound.o base64.o optimize.o smanage.o client.o progress.o leveldb.o startup.o

default : escape.exe

PROF =
# PROF = -pg

# to distribute dynamic: sdl-config --prefix=.
# then ldd escape.exe
# and upload the .so files with the thingy

LDFLAGS = -Wl,-rpath=.

LDLIBS = -lSDL_image -lSDL_net -lSDL_mixer `sdl-config --libs` -ltiff -lpng -ljpeg -lz -lvorbisfile -lvorbis -logg
#  LDLIBS = -lefence

# for multiuser, add -DMULTIUSER -DDATADIR=\"/tmp/escapedata/\" -DSTARTUP_LEVELS=\"/tmp/escapelevels\"
# with appropriate paths to the static data (trailing slash for data dir; no trailing for startup)
CPPFLAGS = `sdl-config --cflags` 
CXXFLAGS = -g -Wall -O ${PROF} -Wno-non-virtual-dtor

escape.exe : ${OFILES}
	g++ ${PROF} -o escape.exe ${LDFLAGS} $^ ${LDLIBS}


default : escape.exe

packsound.exe : util-console.o packsound-console.o
	g++ -o $@ $^ -lSDL_image `sdl-config --static-libs` -ltiff -lpng -ljpeg -lz -lvorbisfile -lvorbis -logg
	strip packsound.exe

sound.o : sound.cc sound_load.h
	g++ ${CXXFLAGS} ${CPPFLAGS} -c -o $@ $<

level.o : level.cc move.h
	g++ ${CXXFLAGS} ${CPPFLAGS} -c -o $@ $<

sound_load.h : sound.pack packsound.cc
	make packsound.exe
	./packsound.exe sound.pack sound


%-console.o : %.cc
	g++ ${CXXFLAGS} ${CPPFLAGS} -DNOSOUND=1 -DUSE_DISPLAY_FORMAT=0 $^ -c -o $@

# but this should be static
screenshot.exe : draw-console.o pngsave-console.o level-console.o font-console.o util-console.o sdlutil-console.o screenshot-console.o animation-console.o sound-console.o message-console.o drawable-console.o progress-console.o
	g++ -g -static -o screenshot.exe $^ -lSDL_image `sdl-config --static-libs` -ltiff -lpng -ljpeg -lz -lvorbisfile -lvorbis -logg

# XX deprecated
convert : convert.o level.o util.o
	g++ -static -lSDL_image -lSDL_net -lSDL_mixer `sdl-config --libs` -ltiff -lpng -ljpeg -lz -lvorbisfile -lvorbis -logg $^ -o convert

.dummy :

version : .dummy
	g++ version.cc -o version.exe
	./version.exe
	make clean
	make escape.exe

LIBFILES=libjpeg.so.62 libogg.so.0 libpng.so.2 libSDL-1.2.so.0 libSDL_net-1.2.so.0 libtiff.so.3 libvorbisfile.so.3 libvorbis.so.0 libz.so.1 libartsc.so.0 libesd.so.0
RELEASEFILES=escape.exe font.png fontsmall.png tiles.png tileutil.png title.png icon.png escape.txt COPYING changelog animation.png splash.png ${LIBFILES}

releasefiles.linux : ${RELEASEFILES}
	echo ${RELEASEFILES} > releasefiles.linux

mkupgrade.exe : mkupgrade.cc md5.cc
	g++ -DLINUX mkupgrade.cc md5.cc -o mkupgrade.exe

CURRENT : .dummy escape.exe releasefiles.linux symlinks.linux deletefiles.linux mkupgrade.exe
	strip escape.exe
	./mkupgrade.exe releasefiles.linux symlinks.linux deletefiles.linux > UPGRADE
	./mkupgrade.exe -v > CURRENT

UPGRADE: CURRENT

release : UPGRADE
	scp -C ${RELEASEFILES} UPGRADE CURRENT root@spacebar.org:/var/www/escape/linux/
	rm -f UPGRADE mkupgrade.exe

zip : escape-beta.tar.gz

escape-beta.tar.gz : escape.exe
	rm -rf /tmp/escape
	rm -f /tmp/escape-beta.tar
	rm -f /tmp/escape-beta.tar.gz
	rm -f escape-beta.tar.gz
	mkdir /tmp/escape
	strip escape.exe
	cp ${RELEASEFILES} /tmp/escape
	cp -a triage /tmp/escape
	cp -a official /tmp/escape
	mkdir /tmp/escape/mylevels
	cp mylevels/index.esi /tmp/escape/mylevels/
	cd /tmp && tar -c escape > escape-beta.tar && gzip escape-beta.tar
	mv /tmp/escape-beta.tar.gz .

zipup : escape-beta.tar.gz
	scp escape-beta.tar.gz root@spacebar.org:/var/www/escape/

source : escape-src.tar.bz2

# 	cd /usr0/src/escape-src && find . -name CVS > /usr0/src/escape-src/.tarignore
#       this includes binaries for OSX...
escape-src.tar.bz2 :
	cd /usr0/src/escape-src && cvs up -dP
	rm -rf /usr0/src/escape-src/web /usr0/src/escape-src/*.es{p,d}
	cd /usr0/src/escape-src && chmod a-x `find . -name "*.h"` `find . -name "*.cc"` `find . -name "*.pack"` `find . -name "*.esx"` `find . -name "*.m"`
	cd /usr0/src && tar -c escape-src --exclude "*CVS*" --exclude "*.svn*" --exclude "*.cvsignore" > /tmp/escape-src.tar
	cd /tmp && bzip2 escape-src.tar
	mv /tmp/escape-src.tar.bz2 .

# XXX two copies.. better if we could make src.tar be a symlink to the versioned tar.
sourceup : source CURRENT
	scp escape-src.tar.bz2 root@spacebar.org:/var/www/escape/source/
	scp escape-src.tar.bz2 root@spacebar.org:/var/www/escape/source/escape-src-`cat CURRENT`.tar.bz2


wc :
	wc -l *.cc *.h

clean :
	rm -f *.o escape.exe core core.[0-9]* gmon.out escape-src.tar.bz2 escape-beta.tar.gz vgcore.*

# end linux makefile
endif

# -------------------------------------------------------------------

ifdef OSX
# makefile for OSX

# XXX sourceforge compile farm is discontinued,
# so vestiges of that might as well be trimmed from here for simplicity

default : escape.exe

# Change this to wherever you put Frameworks directory.
# Frameworks are just glorified shared libraries--they include headers,
# documentation, graphics resources, whatever else programs want to share.
FRAMEWORKS=OSX_build/Frameworks

# Shouldn't be any need to change this,
# unless you are using version 10.0
# like some kind of caveman
VERSION_TARGET=10.1

# sound is disabled to give people time to upgrade the upgrader
# to add it, remove -DNOSOUND and add
# -I${FRAMEWORKS}/SDL_mixer.framework/Versions/Current/Headers
# to CPPFLAGS and add
#  -framework SDL_mixer
# to the g++ line linking below

# don't want to compile with sourceforge's SDL

CPPFLAGS = -arch i386 -arch ppc -I/usr/local/include -I${FRAMEWORKS}/SDL.framework/Versions/Current/Headers -I${FRAMEWORKS}/SDL_net.framework/Versions/Current/Headers -I${FRAMEWORKS}/SDL_mixer.framework/Versions/Current/Headers -I${FRAMEWORKS}/SDL_image.framework/Versions/Current/Headers -D_THREAD_SAFE -DOSX

# good for 10.4 MacBook
# used to use /usr/local/lib
LIBS=-L/usr/lib

escape.exe : main.o level.o sdlutil.o load.o font.o play.o util.o md5.o player.o playerdb.o prompt.o draw.o drawable.o edit.o editprefab.o mainmenu.o upgrade.o http.o textscroll.o message.o update.o editai.o dircache.o upper.o registration.o upload.o rating.o sdlmain.o menu.o prefs.o chunks.o dirindex.o textbox.o analysis.o generator.o prime.o commenting.o cleanup.o mainshow.o handhold.o animation.o dirt.o sound.o base64.o optimize.o smanage.o client.o progress.o leveldb.o startup.o
	export MACOSX_DEPLOYMENT_TARGET=${VERSION_TARGET}
	g++ -arch i386 -arch ppc -F${FRAMEWORKS} -framework SDL_net -framework SDL_image ${LIBS} -framework SDL -framework OpenGL -framework AGL -framework IOKit -framework Carbon -framework Cocoa -framework SDL_mixer $^ -o escape.exe

.dummy :

version : .dummy
	g++ version.cc -o version.exe
	./version.exe
	make clean
	make escape.exe

RELEASEFILES=escape.exe font.png fontsmall.png tiles.png tileutil.png title.png icon.png escape.txt COPYING changelog animation.png splash.png

mkupgrade.exe : mkupgrade.cc md5.cc
	g++ -DOSX mkupgrade.cc md5.cc -o mkupgrade.exe

releasefiles.osx :
	echo ${RELEASEFILES} > releasefiles.osx
	echo OSX_build/Frameworks/SDL_mixer.framework/SDL_mixer >> releasefiles.osx
	echo OSX_build/Frameworks/SDL_mixer.framework/Resources/Info.plist >> releasefiles.osx
	echo OSX_build/Frameworks/SDL_mixer.framework/Resources/pbdevelopment.plist >> releasefiles.osx

UPGRADE : .dummy mkupgrade.exe releasefiles.osx symlinks.osx deletefiles.osx
	strip escape.exe
	./mkupgrade.exe releasefiles.osx symlinks.osx deletefiles.osx > UPGRADE
	./mkupgrade.exe -v > CURRENT

release : UPGRADE
	rm -rf ../release
	mkdir ../release
	cp ${RELEASEFILES} CURRENT UPGRADE ../release/
	cp OSX_build/Frameworks/SDL_mixer.framework/SDL_mixer ../release/OSX_build_Frameworks_SDL_mixer.framework_SDL_mixer
	cp OSX_build/Frameworks/SDL_mixer.framework/Resources/Info.plist ../release/OSX_build_Frameworks_SDL_mixer.framework_Resources_Info.plist
	cp OSX_build/Frameworks/SDL_mixer.framework/Resources/pbdevelopment.plist ../release/OSX_build_Frameworks_SDL_mixer.framework_Resources_pbdevelopment.plist
	rm -f UPGRADE CURRENT mkupgrade.executables

releaseup : release
	cd ../release && scp * root@spacebar.org:/var/www/escape/osx

zip : escape-beta-osx.zip

# OSX_build goes inside an otherwise empty folder called
# Escape.app. The folder should be renamed to Contents.
# inside Contents/MacOS goes all of the regularly distributed
# files.
# the folder Escape.app is zipped to produce the result

# for some reason frameworks need some redundance built with symlinks
# XXX give this deps so it knows when to run
framelinks :
	-mkdir OSX_build/Frameworks/SDL.framework/Versions
	-mkdir OSX_build/Frameworks/SDL.framework/Versions/A
	-mkdir OSX_build/Frameworks/SDL_net.framework/Versions
	-mkdir OSX_build/Frameworks/SDL_net.framework/Versions/A
	-mkdir OSX_build/Frameworks/SDL_image.framework/Versions
	-mkdir OSX_build/Frameworks/SDL_image.framework/Versions/A
	-mkdir OSX_build/Frameworks/SDL_mixer.framework/Versions
	-mkdir OSX_build/Frameworks/SDL_mixer.framework/Versions/A
	cd OSX_build/Frameworks/SDL.framework/Versions/A && ln -s ../../SDL SDL && ln -s ../../Headers Headers && ln -s ../../Resources Resources && cd .. && ln -s A Current
	cd OSX_build/Frameworks/SDL_net.framework/Versions/A && ln -s ../../SDL_net SDL_net && ln -s ../../Headers Headers && ln -s ../../Resources Resources && cd .. && ln -s A Current
	cd OSX_build/Frameworks/SDL_image.framework/Versions/A && ln -s ../../SDL_image SDL_image && ln -s ../../Headers Headers && ln -s ../../Resources Resources && cd .. && ln -s A Current
	cd OSX_build/Frameworks/SDL_mixer.framework/Versions/A && ln -s ../../SDL_mixer SDL_mixer && ln -s ../../Headers Headers && ln -s ../../Resources Resources && cd .. && ln -s A Current

app : escape.exe
	rm -rf /tmp/Escape.app
	rm -f /tmp/escape-beta-osx.zip
	rm -f escape-beta-osx.zip
	mkdir /tmp/Escape.app
	mkdir /tmp/Escape.app/Contents
	mkdir /tmp/Escape.app/Contents/MacOS
	cp -R OSX_build/* /tmp/Escape.app/Contents/
	cp ${RELEASEFILES} /tmp/Escape.app/Contents/MacOS/
	cp -R triage /tmp/Escape.app/Contents/MacOS/
	cp -R official /tmp/Escape.app/Contents/MacOS/
	mkdir /tmp/Escape.app/Contents/MacOS/mylevels
	cp mylevels/index.esi /tmp/Escape.app/Contents/MacOS/mylevels/
	mkdir /tmp/Escape.app/Contents/MacOS/OSX_build
	mkdir /tmp/Escape.app/Contents/MacOS/OSX_build/Frameworks
	rm -rf /tmp/Escape.app/Contents/Frameworks/SDL_mixer.framework
	ln -s ../MacOS/OSX_build/Frameworks/SDL_mixer.framework /tmp/Escape.app/Contents/Frameworks/SDL_mixer.framework
	cp -R OSX_build/Frameworks/SDL_mixer.framework /tmp/Escape.app/Contents/MacOS/OSX_build/Frameworks/
	rm -f /tmp/Escape.app/Contents/Frameworks/SDL.framework/Headers/*.h
	rm -f /tmp/Escape.app/Contents/Frameworks/SDL_image.framework/Headers/*.h
	rm -f /tmp/Escape.app/Contents/Frameworks/SDL_net.framework/Headers/*.h
	rm -f /tmp/Escape.app/Contents/MacOS/OSX_build/SDL_mixer.framework/Headers/*.h
	rm -rf `find /tmp/Escape.app -name CVS`
	rm -rf `find /tmp/Escape.app -name .svn`
	rm -rf `find /tmp/Escape.app -name .DS_Store`

desktop : app
	rm -rf ~/Desktop/Escape.app.old
	-mv ~/Desktop/Escape.app ~/Desktop/Escape.app.old
	cp -R /tmp/Escape.app ~/Desktop/

escape-beta-osx.zip : app
	cd /tmp && zip -r -9 -y escape-beta-osx.zip Escape.app
	rm -f escape-beta-osx.zip
	cp /tmp/escape-beta-osx.zip .

zipup : escape-beta-osx.zip
	scp escape-beta-osx.zip root@spacebar.org:/var/www/escape/

wc :
	wc -l *.cc *.h

clean :
	rm -f *.o escape.exe core core.[0-9]* .DS_Store


# end OSX makefile
endif

# experimental mingw makefile
ifdef MINGW

OFILES = main.o level.o sdlutil.o load.o font.o play.o util.o md5.o player.o playerdb.o prompt.o draw.o drawable.o edit.o editprefab.o mainmenu.o upgrade.o http.o textscroll.o message.o update.o editai.o dircache.o upper.o registration.o upload.o rating.o menu.o prefs.o chunks.o dirindex.o textbox.o analysis.o generator.o prime.o commenting.o cleanup.o mainshow.o handhold.o animation.o dirt.o sound.o base64.o optimize.o smanage.o client.o progress.o leveldb.o startup.o icon.o

default : escape.exe

PROF =
# PROF = -pg

# to distribute dynamic: sdl-config --prefix=.
# then ldd escape.exe
# and upload the .so files with the thingy

LDFLAGS = -Wl,-rpath=.

# -lSDL_mixer
# at end  -lvorbisfile -lvorbis -logg
LDLIBS = -lSDL_image -lSDL_net  `sdl-config --libs` -ltiff -lpng -ljpeg -lz
#  LDLIBS = -lefence

# for multiuser, add -DMULTIUSER -DDATADIR=\"/tmp/escapedata/\" -DSTARTUP_LEVELS=\"/tmp/escapelevels\"
# with appropriate paths to the static data (trailing slash for data dir; no trailing for startup)
CPPFLAGS = -DNOSOUND=1 `sdl-config --cflags` 
CXXFLAGS = -g -Wall -O ${PROF} -Wno-non-virtual-dtor

icon.o : escape.ico escape.rc
	windres -i escape.rc -o $@

escape.exe : ${OFILES}
	g++ ${PROF} -o escape.exe ${LDFLAGS} $^ ${LDLIBS}

default : escape.exe

packsound.exe : util-console.o packsound-console.o
	g++ -o $@ $^ -lSDL_image `sdl-config --static-libs` -ltiff -lpng -ljpeg -lz
	strip packsound.exe

sound.o : sound.cc sound_load.h
	g++ ${CXXFLAGS} ${CPPFLAGS} -c -o $@ $<

level.o : level.cc move.h
	g++ ${CXXFLAGS} ${CPPFLAGS} -c -o $@ $<

animation.o : animation.cc animation.h animation_load.h
	g++ ${CXXFLAGS} ${CPPFLAGS} -c -o $@ $<

sound_load.h : sound.pack packsound.cc
	make packsound.exe
	./packsound.exe sound.pack sound

animation_load.h animation.png animation_decs.h animation_defs.h : animation.pack
	rm -f animation_load.h animation.png animation_decs.h animation_defs.h
	make packpng.exe
	packpng.exe animation.pack animation
	rm -f animation.better
	pngcrush/pngcrush -e .better animation.png
	rm -f animation.png
	mv animation.better animation.png

PNGHEADERS = -I /usr/local/include
# -I ../libpng-1.2.21

%-console.o : %.cc
	g++ ${CXXFLAGS} ${CPPFLAGS} -DNOSOUND=1 -DUSE_DISPLAY_FORMAT=0 ${PNGHEADERS} $^ -c -o $@

# XXXX doesn't seem to run (?)
packpng.exe : util-console.o font-console.o level-console.o sdlutil-console.o packpng-console.o pngsave-console.o winmain-console.o
	g++ -o $@ ${LDFLAGS} $^ ${LDLIBS}

# but this should be static
screenshot.exe : draw-console.o pngsave-console.o level-console.o font-console.o util-console.o sdlutil-console.o screenshot-console.o animation-console.o sound-console.o message-console.o drawable-console.o progress-console.o
	g++ -g -static -o screenshot.exe $^ -lSDL_image `sdl-config --static-libs` -ltiff -lpng -ljpeg -lz

# XX deprecated
convert : convert.o level.o util.o
	g++ -static -lSDL_image -lSDL_net `sdl-config --libs` -ltiff -lpng -ljpeg -lz $^ -o convert

.dummy :

version : .dummy
	g++ version.cc -o version.exe
	./version.exe
	make clean
	make escape.exe

LIBFILES=libjpeg.so.62 libogg.so.0 libpng.so.2 libSDL-1.2.so.0 libSDL_net-1.2.so.0 libtiff.so.3 libvorbisfile.so.3 libvorbis.so.0 libz.so.1 libartsc.so.0 libesd.so.0
RELEASEFILES=escape.exe font.png fontsmall.png tiles.png tileutil.png title.png icon.png escape.txt COPYING changelog animation.png splash.png ${LIBFILES}

releasefiles.linux : ${RELEASEFILES}
	echo ${RELEASEFILES} > releasefiles.linux

mkupgrade.exe : mkupgrade.cc md5.cc
	g++ -DLINUX mkupgrade.cc md5.cc -o mkupgrade.exe

CURRENT : .dummy escape.exe releasefiles.linux symlinks.linux deletefiles.linux mkupgrade.exe
	strip escape.exe
	./mkupgrade.exe releasefiles.linux symlinks.linux deletefiles.linux > UPGRADE
	./mkupgrade.exe -v > CURRENT

UPGRADE: CURRENT

release : UPGRADE
	scp -C ${RELEASEFILES} UPGRADE CURRENT root@spacebar.org:/var/www/escape/linux/
	rm -f UPGRADE mkupgrade.exe

zip : escape-beta.tar.gz

escape-beta.tar.gz : escape.exe
	rm -rf /tmp/escape
	rm -f /tmp/escape-beta.tar
	rm -f /tmp/escape-beta.tar.gz
	rm -f escape-beta.tar.gz
	mkdir /tmp/escape
	strip escape.exe
	cp ${RELEASEFILES} /tmp/escape
	cp -a triage /tmp/escape
	cp -a official /tmp/escape
	mkdir /tmp/escape/mylevels
	cp mylevels/index.esi /tmp/escape/mylevels/
	cd /tmp && tar -c escape > escape-beta.tar && gzip escape-beta.tar
	mv /tmp/escape-beta.tar.gz .

zipup : escape-beta.tar.gz
	scp escape-beta.tar.gz root@spacebar.org:/var/www/escape/

source : escape-src.tar.bz2

# 	cd /usr0/src/escape-src && find . -name CVS > /usr0/src/escape-src/.tarignore
#       this includes binaries for OSX...
escape-src.tar.bz2 :
	cd /usr0/src/escape-src && cvs up -dP
	rm -rf /usr0/src/escape-src/web /usr0/src/escape-src/*.es{p,d}
	cd /usr0/src/escape-src && chmod a-x `find . -name "*.h"` `find . -name "*.cc"` `find . -name "*.pack"` `find . -name "*.esx"` `find . -name "*.m"`
	cd /usr0/src && tar -c escape-src --exclude "*CVS*" --exclude "*.svn*" --exclude "*.cvsignore" > /tmp/escape-src.tar
	cd /tmp && bzip2 escape-src.tar
	mv /tmp/escape-src.tar.bz2 .

# XXX two copies.. better if we could make src.tar be a symlink to the versioned tar.
sourceup : source CURRENT
	scp escape-src.tar.bz2 root@spacebar.org:/var/www/escape/source/
	scp escape-src.tar.bz2 root@spacebar.org:/var/www/escape/source/escape-src-`cat CURRENT`.tar.bz2


wc :
	wc -l *.cc *.h

clean :
	rm -f *.o escape.exe core core.[0-9]* gmon.out escape-src.tar.bz2 escape-beta.tar.gz vgcore.*

# end mingw makefile
endif
