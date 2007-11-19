
default : ml5pgh

WIN_MLTON_FLAGS = @MLton max-heap 300M --
MLTON_FLAGS = -verbose 1 -expert true
# takes forever to compile with profiling on
# -profile time
#  -prefer-abs-paths true -show-def-use ml5pgh.basis.du


# ml5pgh.exe : ml5pgh
#	rm -f ml5pgh.exe
#	cp ml5pgh ml5pgh.exe

ml5pgh : makefile ml5pgh.cm *.sml ast/*.sml codegen/*.sml js/*.sml js/lib/*.sml front/*.sml el/*.sml parser/*.sml util/*.sml cps/*.sml il/*.sml ../../sml-lib/util/*.sml ../../sml-lib/algo/*.sml bytecode/*.sml
	-mlton $(MLTON_FLAGS) ml5pgh.cm
#	grep -v basis ml5pgh.basis.du > ml5pgh.du

clean :
	rm -rf `find . -name "*~"` `find . -type d -name .cm` *.exe ml5pgh *.du mlmon.out
	rm -f bugs/*.b5 bugs/*.js 
	rm -f regression/*.b5 regression/*.js 
	rm -f bench/*.b5 bench/*.js

wc :
	find . -name "*.sml" | grep -v CM | grep -v \\.cm | xargs wc -l

linelen :
	linelen `find . -name "*.sml" | grep -v CM | grep -v \\.cm`
