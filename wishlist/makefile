
default: wishlist.exe preprocess.exe coin.exe wikipedia.exe facebook.exe backform.exe

wishlist.exe : wishlist.cm wishlist.sml
	mlton -output $@ wishlist.cm

preprocess.exe : preprocess.cm preprocess.sml
	mlton -output $@ preprocess.cm

coin.exe : coin.cm coin.sml nmarkov-svg.sml ../sml-lib/data/nmarkov*.sml
	mlton -output $@ coin.cm

wikipedia.exe : wikipedia.cm wikipedia.sml ../sml-lib/data/nmarkov*.sml
	mlton -output $@ wikipedia.cm

facebook.exe : facebook.cm facebook.sml ../sml-lib/data/nmarkov*.sml
	mlton -output $@ facebook.cm

backform.exe : backform.cm backform.sml ../sml-lib/data/nmarkov*.sml
	mlton -output $@ backform.cm

paper.pdf : paper.tex coin1.pdf italiancoin1.pdf wishlist-cdf.pdf scrallbe-screenshot.png
	pdflatex paper.tex
	pdflatex paper.tex
