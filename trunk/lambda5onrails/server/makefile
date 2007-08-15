
default : server5

# old mlton
MLTONFLAGS = -default-ann 'allowImport true'
# new mlton
# MLTONFLAGS = -default-ann 'allowImport true' -default-ann 'sequenceNonUnit warn'

# -prefer-abs-paths true -show-def-use server5.basis.du
server5 : *.sml server5.cm raw-network.c ../lambdac/primop.sml ../lambdac/bytecode/*.sml
	-mlton @MLton max-heap 128m -- $(MLTONFLAGS) server5-cygwin.cm raw-network.c
#	grep -v basis server5.basis.du > server5.du
