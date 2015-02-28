
default: redi.exe fetcher.exe resample.exe

all: redi.exe fetcher.exe

# -fno-strict-aliasing
CXXFLAGS=-Wall -Wno-deprecated -Wno-sign-compare -I/usr/local/include -std=c++11
OPT=-O2

# for 64 bits on windows
CXX=x86_64-w64-mingw32-g++
CC=x86_64-w64-mingw32-g++

MLTON=/c/mlton/bin/mlton.bat

AMD_ARCH=x86_64
# AMDSDK="/c/Program Files (x86)/AMD APP SDK"
AMDSDK="/c/Program Files (x86)/AMD APP SDK/2.9"

CLINCLUDES=-I ${AMDSDK}/include
CLLIBS=-L ${AMDSDK}/lib/${AMD_ARCH}

UTILOBJECTS=../cc-lib/util.o ../cc-lib/arcfour.o ../cc-lib/base/stringprintf.o ../cc-lib/base/logging.o ../cc-lib/stb_image.o ../cc-lib/stb_image_write.o

CPPFLAGS= -DPSS_STYLE=1 -DDUMMY_UI -DHAVE_ASPRINTF -Wno-write-strings -m64 $(OPT) -D__MINGW32__ -DHAVE_ALLOCA -DNOWINSTUFF $(INCLUDES) $(PROFILE) $(FLTO) $(CLINCLUDES) -I ../cc-lib/ --std=c++0x

OBJECTS=${UTILOBJECTS}

# without static, can't find lz or lstdcxx maybe?
LFLAGS=  -m64 -Wl,--subsystem,console $(CLLIBS) -lz -lOpenCL $(OPT) $(FLTO) $(PROFILE) -static

redi.exe : $(OBJECTS) redi.o
	$(CXX) $^ -o $@ $(LFLAGS)

resample.exe : $(OBJECTS) resample.o
	$(CXX) $^ -o $@ $(LFLAGS)

fetcher.exe : fetcher.cm fetcher.sml
	$(MLTON) -output fetcher.exe fetcher.cm

clean :
	rm -f *.o *.exe
