
default : renderhero.exe dumpmidi.exe filterhero.exe

# fyi, turning on exn history slows stuff down
#EXNHISTORY=-const 'Exn.keepHistory true'
EXNHISTORY=
MLTON=mlton @MLton max-heap 500m -- ${EXNHISTORY}

LIB=../sml-lib/files/midi/*.sml ../sml-lib/files/wave/*.sml

renderhero.exe : renderhero.cm renderhero.sml makefile ${LIB}
	${MLTON} -output $@ renderhero.cm

filterhero.exe : filterhero.cm filterhero.sml makefile ${LIB}
	${MLTON} -output $@ filterhero.cm

dumpmidi.exe : dumpmidi.sml dumpmidi.cm makefile ${LIB}
	${MLTON} -output $@ dumpmidi.cm

clean :
	rm -f renderhero-ffi.exe renderhero.exe dumpmidi.exe filterhero.exe *.o core
