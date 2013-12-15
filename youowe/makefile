all : music.js

upload :
	pscp *.js *.png index.html root@spacebar.org:/var/www/youowe/

music.js : overworld.mid
	echo "/* Generated file, do not edit */" > music.js
	../renderhero/dumpmidi overworld.mid overworld >> music.js

