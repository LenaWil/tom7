
default: wishlist.exe preprocess.exe coin.exe wikipedia.exe facebook.exe


wishlist.exe : wishlist.cm wishlist.sml
	mlton -output $@ wishlist.cm

preprocess.exe : preprocess.cm preprocess.sml
	mlton -output $@ preprocess.cm

coin.exe : coin.cm coin.sml nmarkov-svg.sml
	mlton -output $@ coin.cm

wikipedia.exe : wikipedia.cm wikipedia.cm
	mlton -output $@ wikipedia.cm

facebook.exe : facebook.cm facebook.cm
	mlton -output $@ facebook.cm
