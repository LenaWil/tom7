
default : maildar

# old mlton
# MLTONFLAGS = -default-ann 'allowImport true'
# new mlton
# MLTONFLAGS = @MLton max-heap 128m -- -default-ann 'allowFFI true' -default-ann 'sequenceNonUnit warn'
# really old mlton
MLTONFLAGS =

maildar : *.sml maildar.cm raw-network.c 
	-mlton $(MLTONFLAGS) maildar.cm raw-network.c

clean :
	rm -rf *~ .cm CM core mlmon.out *.du *.o
