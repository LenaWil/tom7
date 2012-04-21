AAPH = aaph
STDLIB = /usr/src/aphasia2/stdlib

default : save.aph

%.aph : %.aa tinyworld.aah ${STDLIB}/cgi.aah
	$(AAPH) -I ../ $<

clean :
	rm -f *.aph core
