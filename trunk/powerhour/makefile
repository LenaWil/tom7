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

samplegrid2x2.exe : samplegrid2x2.cm samplegrid2x2.sml samples-tf.sml
	${MLTON} -output $@ samplegrid2x2.cm

sample60min2players6states.svg : checkpoint-60m-2p-6s.tf samplegrid2x2.exe
	./samplegrid2x2.exe -minutes 60 -players 2 -states 6

sample60min2players7states.svg : checkpoint-60m-2p-7s.tf samplegrid2x2.exe
	./samplegrid2x2.exe -minutes 60 -players 2 -states 7

sample180min2players7states.svg : checkpoint-180m-2p-7s.tf samplegrid2x2.exe
	./samplegrid2x2.exe -minutes 180 -players 2 -states 7 -nolines -nonums

graphics : sample60min2players6states.svg sample60min2players7states.svg sample180min2players7states.svg
