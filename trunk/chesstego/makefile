default : chesstego.exe paper.pdf

# XXX
chesstego3.exe : chesstego.sml chesstego.cm
	mlton -output $@ chesstego.cm

paper.pdf : paper.tex king2.tex
	pdflatex paper
#	pdflatex paper
