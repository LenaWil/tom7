default : chesstego.exe paper.pdf

chesstego.exe : chesstego.sml chesstego.cm
	mlton -output $@ chesstego.cm

chesswho.exe : chesswho.sml chesswho.cm
	mlton -output $@ chesswho.cm

paper.pdf : paper.tex king2.tex paper.bib
	pdflatex paper
#	bibtex paper
#	pdflatex paper
#	pdflatex paper
