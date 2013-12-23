
paper.pdf : paper.tex paper.bib powerday3.pdf 3and2.pdf
	pdflatex paper
	-bibtex paper
	pdflatex paper


clean :
	rm -f *.log *.aux *.bbl *.blg *~ paper.pdf
