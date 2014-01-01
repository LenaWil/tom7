
MLTON=mlton @MLton max-heap 1.5G --

default : midinverse.exe

midinverse.exe : midinverse.cm midinverse.sml
	${MLTON} -output $@ midinverse.cm
