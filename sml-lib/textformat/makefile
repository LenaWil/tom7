
default : tftest.exe test

MLTON=/c/mlton/bin/mlton.bat

tfcompiler.exe : tfcompiler.mlb tfcompiler.sml description-parser.sml
	${MLTON} -output $@ tfcompiler.mlb

test-tf.sml : test.tfdesc tfcompiler.exe
	./tfcompiler.exe test.tfdesc

tftest.exe : test-tf.sml test.sml test.mlb
	${MLTON} -output $@ test.mlb

test : tftest.exe
	./tftest.exe
