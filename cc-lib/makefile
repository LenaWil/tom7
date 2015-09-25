
default : heap_test.exe rle_test.exe interval-tree_test.exe threadutil_test.exe

TESTCOMPILE=stb_image_write.o stb_image.o

BASE=base/logging.o base/stringprintf.o

# for 64 bits on windows
# CXX=x86_64-w64-mingw32-g++
# CC=x86_64-w64-mingw32-g++
# CXXFLAGS=-I. --std=c++11 -O2 -static

# For linux, others...
# (pthreads can't be linked statically)
CXXFLAGS=-I. --std=c++11 -O2

heap_test.o : heap_test.cc heap.h
	$(CXX) $(CXXFLAGS) $< -o $@ -c

heap_test.exe : heap_test.o
	$(CXX) $(CXXFLAGS) $^ -o $@

rle_test.o : rle_test.cc rle.h
	$(CXX) $(CXXFLAGS) $< -o $@ -c

rle_test.exe : rle_test.o rle.o $(BASE) arcfour.o
	$(CXX) $(CXXFLAGS) $^ -o $@

interval-tree_test.exe : interval-tree_test.o $(BASE) arcfour.o
	$(CXX) $(CXXFLAGS) $^ -o $@

threadutil_test.exe : threadutil.h threadutil_test.o $(BASE)
	$(CXX) $(CXXFLAGS) $^ -o $@ -lpthread

clean :
	rm -f *.o *.exe
