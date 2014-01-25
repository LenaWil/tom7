
# MLTON=mlton @MLton max-heap 1.5G --
MLTON=/c/mlton/bin/mlton.bat -target x86_64-w64-mingw32 -codegen amd64

default : midinverse.exe songs newwaves # waves

newwaves : sensations-rot6.wav entertainer-rot6.wav

songs : sensations-inverse.mid entertainer-inverse.mid sensations-rot6.mid entertainer-rot6.mid
waves : sensations-inverse.wav entertainer-inverse.wav newwaves

midinverse.exe : midinverse.cm midinverse.sml
	${MLTON} -output $@ midinverse.cm

%-rot6.mid : %.mid midinverse.exe makefile
	./midinverse.exe $< -o $@ -rotoctave -octaveperm 6,7,8,9,10,11,0,1,2,3,4,5
#11,10,9,8,7,6,5,4,3,2,1,0
# 6,7,8,9,10,11,0,1,2,3,4,5

%-inverse.mid : %.mid midinverse.exe makefile
	./midinverse.exe $< -o $@ -invert -range -gamut

%.wav : %.mid ../renderhero/renderhero.exe
	time ../renderhero/renderhero.exe $< -gain 0.08

paper.pdf : paper.tex paper.bib
	pdflatex paper
	-bibtex paper
	pdflatex paper

clean :
	rm -f *.log *.aux *.bbl *.blg *~ paper.pdf
