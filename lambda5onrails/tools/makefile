
all: makepic

#  -const 'Exn.keepHistory true'
makepic : *.sml makepic.cm pngsave.o makefile
	mlton @MLton max-heap 350m -- -default-ann 'allowFFI true' -link-opt '-lpng' makepic.cm pngsave.o

pngsave.o : pngsave.c makefile
	gcc -O -I /sw/include pngsave.c -c -o pngsave.o
