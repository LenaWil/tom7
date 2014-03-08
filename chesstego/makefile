default : chesstego.exe paper.pdf

# XXX
chesstego.exe : chesstego.sml chesstego.cm
	mlton -output $@ chesstego.cm

paper.pdf : paper.tex king2.tex paper.bib
	pdflatex paper
	bibtex paper
	pdflatex paper
	pdflatex paper
