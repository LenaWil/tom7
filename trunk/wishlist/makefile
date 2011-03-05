
default: wishlist.exe preprocess.exe coin.exe wikipedia.exe facebook.exe


wishlist.exe : wishlist.cm wishlist.sml makefile
	mlton -output $@ wishlist.cm

preprocess.exe : preprocess.cm preprocess.sml makefile
	mlton -output $@ preprocess.cm

coin.exe : coin.cm coin.sml makefile
	mlton -output $@ coin.cm

wikipedia.exe : wikipedia.cm wikipedia.cm makefile
	mlton -output $@ wikipedia.cm

facebook.exe : facebook.cm facebook.cm makefile
	mlton -output $@ facebook.cm
