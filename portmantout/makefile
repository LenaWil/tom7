
default: spans.exe

all: particles.exe join.exe grid.exe portmantout.exe validate.exe scroll.exe spans.exe threadutil_test.exe makeparticles_test.exe

# -fno-strict-aliasing
CXXFLAGS=-Wall -Wno-deprecated -Wno-sign-compare -I/usr/local/include -I/usr/include -ISDL/include -std=c++11 
OPT=-O2

# for 64 bits on windows
CXX=x86_64-w64-mingw32-g++
CC=x86_64-w64-mingw32-g++
# CXX=g++
# CC=g++

UTILOBJECTS=util.o arcfour.o stringprintf.o logging.o textsvg.o color-util.o stb_image_write.o stb_image.o

#  -D__MINGW32__
CPPFLAGS= -DPSS_STYLE=1 -DDUMMY_UI -DHAVE_ASPRINTF -Wno-write-strings -m64 $(OPT) -DHAVE_ALLOCA $(INCLUDES) $(PROFILE) $(FLTO) $(CLINCLUDES) -I ../cc-lib/ --std=c++11

ALLDEPS=makefile ../cc-lib/interval-tree.h ../cc-lib/interval-tree-json.h

%.o : %.cc $(ALLDEPS)
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
	@echo -n "."

%.o : ../cc-lib/%.cc $(ALLDEPS)
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
	@echo -n "."

%.o : ../cc-lib/base/%.cc $(ALLDEPS)
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
	@echo -n "."


OBJECTS=${UTILOBJECTS}

# without static, can't find lz or lstdcxx maybe?
LFLAGS= -m64 -Wl,--subsystem,console $(CLLIBS) -lz $(OPT) $(FLTO) $(PROFILE) -static
# LFLAGS = -m64 -Wl $(CLLIBS) -lz $(OPT) $(FLTO) $(PROFILE)

table-two.tex : join.exe
	./join.exe

paper.pdf : paper.tex table-two.tex
	pdflatex paper.tex
#	pdflatex paper.tex

portmantout.exe : $(OBJECTS) portmantout.o makeparticles.o makejoin.o
	$(CXX) $^ -o $@ $(LFLAGS)

particles.exe : $(OBJECTS) particles.o makeparticles.o
	$(CXX) $^ -o $@ $(LFLAGS)

join.exe : $(OBJECTS) join.o makejoin.o
	$(CXX) $^ -o $@ $(LFLAGS)

validate.exe : $(OBJECTS) validate.o
	$(CXX) $^ -o $@ $(LFLAGS)

spans.exe : $(OBJECTS) spans.o
	$(CXX) $^ -o $@ $(LFLAGS)

makeparticles_test.exe:  $(OBJECTS) makeparticles_test.o
	$(CXX) $^ -o $@ $(LFLAGS)

grid.exe : $(OBJECTS) grid.o
	$(CXX) $^ -o $@ $(LFLAGS)

scroll.exe : $(OBJECTS) scroll.o
	$(CXX) $^ -o $@ $(LFLAGS)

threadutil_test.exe : $(OBJECTS) threadutil_test.o
	$(CXX) $^ -o $@ $(LFLAGS)

clean :
	rm -f *.o *.exe
