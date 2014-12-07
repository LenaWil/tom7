all : music.js map.js

MLTON=/c/mlton/bin/mlton.bat -target x86_64-w64-mingw32 -codegen amd64

upload :
	pscp *.js *.png *.wav index.html root@spacebar.org:/var/www/entire/

svgtomap.exe : svgtomap.cm svgtomap.sml
	$(MLTON) svgtomap.cm

map.js : svgtomap.exe map.svg
	./svgtomap.exe map.svg

# 
# music.js : music/theme.mid music/menu1.mid music/power.mid
# 	echo "/* Generated file, do not edit */" > music.js
# 	../renderhero/dumpmidi music/theme.mid song_theme >> music.js
# 	../renderhero/dumpmidi music/menu1.mid song_menu >> music.js
# 	../renderhero/dumpmidi music/power.mid song_power >> music.js
# 	dos2unix music.js
# 
