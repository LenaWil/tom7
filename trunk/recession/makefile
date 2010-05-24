
default: recession.exe

MC=mysql_config
# MC=/usr0/src/mysql-standard-5.0.4-beta-pc-linux-gnu-i686/bin/mysql_config

LO_SDL="-lSDL_image -lSDL_net -ltiff -lpng -ljpeg -lz `sdl-config --libs`"
LO_MYSQL=`echo "-L/usr0/src/mysql-standard-5.0.4-beta-pc-linux-gnu-i686/lib -lmysqlclient_r -lz -lpthread -lcrypt -lnsl -lm -lpthread -lc -lnss_files -lnss_dns -lresolv -lc -lnss_files -lnss_dns -lresolv" | sed -e 's/ / -link-opt /g'`

recession.exe : recession.cm *.sml ../sml-lib/mlton/mysql/*.sml sdlml_console.o sdlnet.o mysql.o recession.cm
	mlton -output $@ -default-ann 'allowFFI true' -link-opt ${LO_SDL} -link-opt ${LO_MYSQL} $< mysql.o sdlml_console.o sdlnet.o

mysql.o : ../sml-lib/mlton/mysql/mysql.c
	gcc -o $@ -c -O `${MC} --cflags` `${MC} --include` $<

sdlml_console.o : ../sdlml/sdlml.c
	gcc -DLINUX -DCONSOLE_MODE -O `sdl-config --cflags` -c $< -o $@

sdlnet.o : ../sdlml/sdlnet.c
	gcc -DLINUX -O `sdl-config --cflags` -c $< -o $@
