default : screens/makefile mask.png

gencrop.exe : gencrop.cc
	gcc gencrop.cc -o gencrop.exe -O

screens/makefile : gencrop.exe
	./gencrop.exe > screens/makefile

mask.png : mask.bmp
	 /bin/convert $^ -sample 384x384\! $@
	 # ??
	 rm -f mask-1.png
	 mv mask-0.png mask.png
