
default : heap_test.exe rle_test.exe

BASE=base/logging.o base/stringprintf.o

# for 64 bits on windows
CXX=x86_64-w64-mingw32-g++
CC=x86_64-w64-mingw32-g++

CXXFLAGS=-I. --std=c++11 -O2 -static

heap_test.o : heap_test.cc heap.h
	$(CXX) $(CXXFLAGS) $< -o $@ -c

heap_test.exe : heap_test.o
	$(CXX) $(CXXFLAGS) $^ -o $@

rle_test.o : rle_test.cc rle.h
	$(CXX) $(CXXFLAGS) $< -o $@ -c

rle_test.exe : rle_test.o rle.o $(BASE) arcfour.o
	$(CXX) $(CXXFLAGS) $^ -o $@

clean :
	rm -f *.o *.exe
