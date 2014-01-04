
default: helloworld.exe

all: helloworld.exe

# -fno-strict-aliasing
CXXFLAGS=-Wall -Wno-deprecated -Wno-sign-compare -I/usr/local/include 
OPT=-O

# for 64 bits on windows
CXX=x86_64-w64-mingw32-g++
CC=x86_64-w64-mingw32-g++
SDLARCH=x64

# If you don't have SDL, you can leave these out, and maybe it still works.
CCNETWORKING= -DMARIONET=1 -I SDL/include -I SDL_net
LINKSDL=  -mno-cygwin -lm -luser32 -lgdi32 -lwinmm -ldxguid
LINKNETWORKING= $(LINKSDL) -lwsock32 -liphlpapi

AMD_ARCH=x86_64
# AMDSDK="/c/Program Files (x86)/AMD APP SDK"
AMDSDK="/c/Program Files (x86)/AMD APP SDK/2.9"

CLINCLUDES=-I ${AMDSDK}/include
CLLIBS=-L ${AMDSDK}/lib/${AMD_ARCH}

#  -DNOUNZIP
CPPFLAGS= $(CCNETWORKING) -DPSS_STYLE=1 -DDUMMY_UI -DHAVE_ASPRINTF -Wno-write-strings -m64 $(OPT) -D__MINGW32__ -DHAVE_ALLOCA -DNOWINSTUFF $(INCLUDES) $(PROFILE) $(FLTO) $(CLINCLUDES) --std=c++0x
#  CPPFLAGS=-DPSS_STYLE=1 -DDUMMY_UI -DHAVE_ASPRINTF -Wno-write-strings -m64 -O -DHAVE_ALLOCA -DNOWINSTUFF $(PROFILE) -g

OBJECTS=helloworld.o

%.pb.cc: %.proto
	$(PROTOC) $< --cpp_out=.

%.pb.h: %.proto
	$(PROTOC) $< --cpp_out=.

# without static, can't find lz or lstdcxx maybe?
LFLAGS=  -m64 -Wl,--subsystem,console $(CLLIBS) -lz -lOpenCL $(OPT) $(FLTO) $(PROFILE) -static
# -Wl,--subsystem,console
# -static -fwhole-program
# -static

# LPNGFLAGS = -Llibpng -m64 -Wl,--subsystem,console $(LINKNETWORKING) -lpng16 -lz $(OPT) $(FLTO) $(PROFILE) -static

helloworld.exe : $(OBJECTS) helloworld.o
	$(CXX) $^ -o $@ $(LFLAGS)

clean :
	rm -f *.o *.exe

