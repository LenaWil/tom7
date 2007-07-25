
default : lambdac

# XXX Stops at type checking!
WINDOWS_MLTON_FLAGS = @MLton max-heap 300M --
MLTON_FLAGS = -expert true -prefer-abs-paths true -show-def-use lambdac.basis.du -stop tc 

# lambdac.exe : lambdac
#	rm -f lambdac.exe
#	cp lambdac lambdac.exe

lambdac : makefile lambdac.cm *.sml front/*.sml el/*.sml parser/*.sml util/*.sml cps/*.sml il/*.sml ../../sml-lib/util/*.sml ../../sml-lib/algo/*.sml
	mlton $(MLTON_FLAGS) lambdac.cm
	grep -v basis lambdac.basis.du > lambdac.du

# should remove some generated files in runtime/...
clean :
	rm -rf `find . -name "*~"` `find . -type d -name .cm` *.exe lambdac *.du

wc :
	find . -name "*.sml" | grep -v CM | grep -v \\.cm | xargs wc -l

linelen :
	linelen `find . -name "*.sml" | grep -v CM | grep -v \\.cm`
