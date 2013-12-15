all : music.js

upload :
	pscp *.js *.png index.html root@spacebar.org:/var/www/youowe/

music.js : overworld.mid vampires.mid escape.mid
	echo "/* Generated file, do not edit */" > music.js
	../renderhero/dumpmidi overworld.mid song_overworld >> music.js
	../renderhero/dumpmidi vampires.mid song_vampires >> music.js
	../renderhero/dumpmidi escape.mid song_escape >> music.js

