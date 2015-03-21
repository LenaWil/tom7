
default: particles.exe join.exe grid.exe

all: particles.exe join.exe paper.pdf grid.exe

# -fno-strict-aliasing
CXXFLAGS=-Wall -Wno-deprecated -Wno-sign-compare -I/usr/local/include -I/usr/include -ISDL/include -std=c++11 
OPT=-O2

# for 64 bits on windows
CXX=x86_64-w64-mingw32-g++
CC=x86_64-w64-mingw32-g++

UTILOBJECTS=util.o arcfour.o stringprintf.o logging.o textsvg.o

CPPFLAGS= -DPSS_STYLE=1 -DDUMMY_UI -DHAVE_ASPRINTF -Wno-write-strings -m64 $(OPT) -D__MINGW32__ -DHAVE_ALLOCA -DNOWINSTUFF $(INCLUDES) $(PROFILE) $(FLTO) $(CLINCLUDES) -I ../cc-lib/ --std=c++11

%.o : %.cc makefile
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
	@echo -n "."

%.o : ../cc-lib/%.cc makefile
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
	@echo -n "."

%.o : ../cc-lib/base/%.cc makefile
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
	@echo -n "."


OBJECTS=${UTILOBJECTS}

# without static, can't find lz or lstdcxx maybe?
LFLAGS= -m64 -Wl,--subsystem,console $(CLLIBS) -lz $(OPT) $(FLTO) $(PROFILE) -static

table-two.tex : join.exe
	./join.exe

paper.pdf : paper.tex table-two.tex
	pdflatex paper.tex
#	pdflatex paper.tex

# portmantout.exe : $(OBJECTS) $(SDLOBJECTS) portmantout.o
# 	$(CXX) $^ -o $@ $(LFLAGS)

particles.exe : $(OBJECTS) $(SDLOBJECTS) particles.o
	$(CXX) $^ -o $@ $(LFLAGS)

join.exe : $(OBJECTS) $(SDLOBJECTS) join.o makejoin.o
	$(CXX) $^ -o $@ $(LFLAGS)

grid.exe : $(OBJECTS) $(SDLOBJECTS) grid.o
	$(CXX) $^ -o $@ $(LFLAGS)

clean :
	rm -f *.o *.exe
