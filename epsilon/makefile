
default : fetcher.exe extract.exe paper.pdf

MLTON=/c/mlton/bin/mlton.bat

fetcher.exe : fetcher.cm fetcher.sml
	$(MLTON) -output fetcher.exe fetcher.cm

extract.exe : extract.cm extract.sml
	$(MLTON) -output extract.exe extract.cm

paper.pdf : paper.tex paper.bib spec.pdf epsilondelta.pdf
	pdflatex paper
	-bibtex paper
	pdflatex paper

clean :
	rm -f *.log *.aux *.bbl *.blg *~ paper.pdf *.exe
