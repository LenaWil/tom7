
default: wishlist.exe preprocess.exe


wishlist.exe : wishlist.cm wishlist.sml makefile
	mlton -output $@ wishlist.cm

preprocess.exe : preprocess.cm preprocess.sml makefile
	mlton -output $@ preprocess.cm
