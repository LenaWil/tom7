
default : server5

server5 : *.sml server5.cm raw-network.c
	-mlton -prefer-abs-paths true -show-def-use server5.basis.du -default-ann 'allowFFI true' server5.cm raw-network.c
	grep -v basis server5.basis.du > server5.du
