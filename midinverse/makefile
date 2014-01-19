
MLTON=mlton @MLton max-heap 1.5G --

default : midinverse.exe songs waves

songs : sensations-inverse.mid entertainer-inverse.mid
waves : sensations-inverse.wav entertainer-inverse.wav

midinverse.exe : midinverse.cm midinverse.sml
	${MLTON} -output $@ midinverse.cm

%-inverse.mid : %.mid midinverse.exe
	./midinverse.exe $< -o $@ -range -gamut

%.wav : %.mid ../renderhero/renderhero.exe
	../renderhero/renderhero.exe $< -gain 0.01
