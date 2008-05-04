
default : maildar

# old mlton
# MLTONFLAGS = -default-ann 'allowImport true'
# new mlton
MLTONFLAGS = -default-ann 'allowFFI true' -default-ann 'sequenceNonUnit warn'
# really old mlton
# MLTONFLAGS =

raw-network.o : raw-network.c
	gcc -Wall -O2 raw-network.c -c -o raw-network.o

maildar : *.sml maildar.cm raw-network.o makefile
	-mlton $(MLTONFLAGS) maildar.cm raw-network.o

clean :
	rm -rf *~ .cm CM core mlmon.out *.du *.o
