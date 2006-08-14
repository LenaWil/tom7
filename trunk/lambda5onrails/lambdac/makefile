
default : lambdac.exe

MLTON_FLAGS = @MLton max-heap 200M --

lambdac.exe : lambdac
	rm -f lambdac.exe
	cp lambdac lambdac.exe

lambdac : makefile lambdac.cm *.sml front/*.sml el/*.sml parser/*.sml util/*.sml cps/*.sml il/*.sml ../../sml-lib/util/*.sml ../../sml-lib/algo/*.sml
	mlton $(MLTON_FLAGS) lambdac.cm

# should remove some generated files in runtime/...
clean :
	rm -f `find . -name "*~"` *.exe lambdac

wc :
	find . -name "*.sml" | grep -v CM | xargs wc -l

linelen :
	linelen `find . -name "*.sml" | grep -v CM`
