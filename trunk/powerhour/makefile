default: powerhour-sample.exe samplegrid2x2.exe

# MLTON=mlton -target x86_64-w64-mingw32 -codegen amd64
MLTON=mlton @MLton max-heap 1.5G --

powerhour : powerhour.cm powerhour.sml
	${MLTON} -output $@ powerhour.cm

powerhour-sample.exe: powerhour-sample.cm *.sml samples-tf.sml
	${MLTON} -output $@ powerhour-sample.cm

tfcompiler.exe : ../sml-lib/textformat/*
	${MLTON} -output $@ ../sml-lib/textformat/tfcompiler.cm

samples-tf.sml : samples.tfdesc tfcompiler.exe
	./tfcompiler.exe samples.tfdesc

cube.exe : cube.cm cube.sml samples-tf.sml
	${MLTON} -output $@ cube.cm

samplegrid2x2.exe : samplegrid2x2.cm samplegrid2x2.sml samples-tf.sml
	${MLTON} -output $@ samplegrid2x2.cm

sample60min2players6states.svg : checkpoint-60m-2p-6s.tf samplegrid2x2.exe
	./samplegrid2x2.exe -minutes 60 -players 2 -states 6

sample60min2players7states.svg : checkpoint-60m-2p-7s.tf samplegrid2x2.exe
	./samplegrid2x2.exe -minutes 60 -players 2 -states 7

sample180min2players7states.svg : checkpoint-180m-2p-7s.tf samplegrid2x2.exe
	./samplegrid2x2.exe -minutes 180 -players 2 -states 7 -nolines -nonums

sample60min3players3states.svg : checkpoint-60m-3p-3s.tf cube.exe
#	./cube.exe -minutes 60 -players 3 -states 3 -nolines -nonums -yaw 15 -pitch 15 -roll 15
	./cube.exe -minutes 60 -players 3 -states 3 -nolines -nonums -yaw 12 -pitch 18 -roll 17

graphics : sample60min2players6states.svg sample60min2players7states.svg sample180min2players7states.svg sample60min3players3states.svg

