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