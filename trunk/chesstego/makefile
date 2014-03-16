default : chesstego.exe chessycrush.exe paper.pdf

chesstego.exe : chesstego.sml chesstego.cm
	mlton -output $@ chesstego.cm

# deleteme: never did anything here since it's trivial
# as described in the paper
chesswho.exe : chesswho.sml chesswho.cm
	mlton -output $@ chesswho.cm

chessycrush.exe : chessycrush.sml chessycrush.cm
	mlton -output $@ chessycrush.cm

paper.pdf : paper.tex king2.tex paper.bib
	pdflatex paper
#	bibtex paper
#	pdflatex paper
#	pdflatex paper
