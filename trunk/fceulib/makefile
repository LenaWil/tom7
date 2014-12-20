
# Makefile made by tom7.
default: emulator_test.exe fm2tocc.exe

all: emulator_test.exe

# -fno-strict-aliasing
# -std=c++11
CXXFLAGS=-Wall -Wno-deprecated -Wno-sign-compare -I/usr/local/include 
OPT=-O2

ifdef OSX
CXX=g++
CC=gcc
else
# for 64 bits on windows
CXX=x86_64-w64-mingw32-g++
CC=x86_64-w64-mingw32-g++
WINCFLAGS= -D__MINGW32__
WINLINK=-Wl,--subsystem,console -static
endif

# If you don't have SDL, you can leave these out, and maybe it still works.
LINKSDL= -mno-cygwin -lm -luser32 -lgdi32 -lwinmm -ldxguid

# XXX probably don't need this
INCLUDES=-I "../cc-lib" -I "../cc-lib/city"

CPPFLAGS=-DPSS_STYLE=1 -DDUMMY_UI -DHAVE_ASPRINTF -Wno-write-strings -m64 $(OPT) $(WINCFLAGS) -DHAVE_ALLOCA -DNOWINSTUFF $(INCLUDES) $(PROFILE) $(FLTO) --std=c++11

# Probably shouldn't need...
CCLIBOBJECTS=../cc-lib/util.o ../cc-lib/arcfour.o ../cc-lib/base/logging.o ../cc-lib/base/stringprintf.o ../cc-lib/city/city.o ../cc-lib/textsvg.o ../cc-lib/rle.o

MAPPEROBJECTS=mappers/24and26.o mappers/51.o mappers/69.o mappers/77.o mappers/40.o mappers/6.o mappers/71.o mappers/79.o mappers/41.o mappers/61.o mappers/72.o mappers/80.o mappers/42.o mappers/62.o mappers/73.o mappers/85.o mappers/46.o mappers/65.o mappers/75.o mappers/emu2413.o mappers/50.o mappers/67.o mappers/76.o mappers/mmc2and4.o

# XXX: Probably a bunch of this can go?
# utils/unzip.o removed -- needs lz
# utils/convertutf8.o
UTILSOBJECTS= utils/general.o utils/memory.o utils/crc32.o utils/guid.o utils/endian.o utils/md5.o utils/xstring.o utils/unzip.o

BOARDSOBJECTS=boards/01-222.o boards/32.o boards/gs-2013.o boards/103.o boards/33.o boards/h2288.o boards/106.o boards/34.o boards/karaoke.o boards/108.o boards/3d-block.o boards/kof97.o boards/112.o boards/411120-c.o boards/konami-qtai.o boards/116.o boards/43.o boards/ks7012.o boards/117.o boards/57.o boards/ks7013.o boards/120.o boards/603-5052.o boards/ks7017.o boards/121.o boards/68.o boards/ks7030.o boards/12in1.o boards/8157.o boards/ks7031.o boards/15.o boards/82.o boards/ks7032.o boards/151.o boards/8237.o boards/ks7037.o boards/156.o boards/830118C.o boards/ks7057.o boards/164.o boards/88.o boards/le05.o boards/168.o boards/90.o boards/lh32.o boards/17.o boards/91.o boards/lh53.o boards/170.o boards/95.o boards/malee.o boards/175.o boards/96.o boards/mmc1.o boards/176.o boards/99.o boards/mmc3.o boards/177.o boards/__dummy_mapper.o boards/mmc5.o boards/178.o boards/a9711.o boards/n-c22m.o boards/179.o boards/a9746.o boards/n106.o boards/18.o boards/ac-08.o boards/n625092.o boards/183.o boards/addrlatch.o boards/novel.o boards/185.o boards/ax5705.o boards/onebus.o boards/186.o boards/bandai.o boards/pec-586.o boards/187.o boards/bb.o boards/sa-9602b.o boards/189.o boards/bmc13in1jy110.o boards/sachen.o boards/193.o boards/bmc42in1r.o boards/sc-127.o boards/199.o boards/bmc64in1nr.o boards/sheroes.o boards/208.o boards/bmc70in1.o boards/sl1632.o boards/222.o boards/bonza.o boards/smb2j.o boards/225.o boards/bs-5.o boards/subor.o boards/228.o boards/cityfighter.o boards/super24.o boards/230.o boards/dance2000.o boards/supervision.o boards/232.o boards/datalatch.o boards/t-227-1.o boards/234.o boards/deirom.o boards/t-262.o boards/235.o boards/dream.o boards/tengen.o boards/244.o boards/edu2000.o boards/tf-1201.o boards/246.o boards/famicombox.o boards/transformer.o boards/252.o boards/fk23c.o boards/vrc2and4.o boards/253.o boards/ghostbusters63in1.o boards/vrc7.o boards/28.o boards/gs-2004.o boards/yoko.o

INPUTOBJECTS=input/arkanoid.o input/ftrainer.o input/oekakids.o input/suborkb.o input/bworld.o input/hypershot.o input/powerpad.o input/toprider.o input/cursor.o input/mahjong.o input/quiz.o input/zapper.o input/fkb.o input/mouse.o input/shadow.o

FCEUOBJECTS=cart.o config.o debug.o drawing.o emufile.o fceu.o fds.o file.o filter.o ines.o input.o movie.o oldmovie.o palette.o ppu.o sound.o state.o unif.o video.o vsuni.o wave.o x6502.o

# drivers/common/config.o drivers/common/configSys.o drivers/common/cheat.o
DRIVERS_COMMON_OBJECTS=drivers/common/args.o drivers/common/nes_ntsc.o drivers/common/scale2x.o drivers/common/scale3x.o drivers/common/scalebit.o drivers/common/hq2x.o drivers/common/vidblit.o drivers/common/hq3x.o

EMUOBJECTS=$(FCEUOBJECTS) $(MAPPEROBJECTS) $(UTILSOBJECTS) $(PALLETESOBJECTS) $(BOARDSOBJECTS) $(INPUTOBJECTS) $(DRIVERS_COMMON_OBJECTS)

# included in all tests, etc.
BASEOBJECTS=$(CCLIBOBJECTS)

FCEULIB_OBJECTS=emulator.o headless-driver.o
# simplefm2.o emulator.o util.o

OBJECTS=$(BASEOBJECTS) $(EMUOBJECTS) $(FCEULIB_OBJECTS)

# without static, can't find lz or lstdcxx maybe?
LFLAGS= -m64 $(WINLINK) $(LINKNETWORKING) -lz $(OPT) $(FLTO) $(PROFILE)
# -Wl,--subsystem,console
# -static -fwhole-program
# -static

fm2tocc.exe : $(OBJECTS) fm2tocc.o simplefm2.o
	$(CXX) $^ -o $@ $(LFLAGS)

emulator_test.exe : $(OBJECTS) emulator_test.o
	$(CXX) $^ -o $@ $(LFLAGS)

test : emulator_test.exe
	time ./emulator_test.exe

clean :
	rm -f *_test.exe *.o $(EMUOBJECTS) $(CCLIBOBJECTS) gmon.out
