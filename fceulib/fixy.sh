#!/bin/bash

set +x

# 2606 vs 2607
REV1=before
REV2=after

DIR1=fix-${REV1}
DIR2=fix-${REV2}

rm -f ${DIR1}/.sav ${DIR1}/.sav
rm -f ${DIR1}/trace.bin ${DIR2}/trace.bin
rm -f trace1.txt trace2.txt

# emulator.h emulator.cc

# x6502.cc state.cc
FILES="ppu.cc input.cc emulator_test.cc trace.cc trace.h tracing.cc tracing.h"
echo "Copying " ${FILES}
cp ${FILES} ${DIR1}/
cp ${FILES} ${DIR2}/

cd ${DIR1}
make clean
make -j 20 emulator_test.exe || exit -1 
./emulator_test.exe --output-file results.txt --romdir ../fix
cd ..

cd ${DIR2}
make clean
make -j 20 emulator_test.exe || exit -1
./emulator_test.exe --output-file results.txt --romdir ../fix
cd ..

cat ${DIR1}/results.txt ${DIR2}/results.txt


#make -j 20 difftrace.exe || exit -1
# /difftrace.exe ${DIR1}/trace.bin ${DIR2}/trace.bin

# grep out lines that merely were changes to/from "0 0 0 0" (not loaded)
# and then show only the insertions. This will be just the files that
# changed their actual hashes.
# diff ${DIR1}/results.txt ${DIR2}/results.txt | grep -v "0 0 0 0" | grep '>'

make -j 20 difftrace.exe dumptrace.exe || exit -1
./difftrace.exe ${DIR1}/trace.bin ${DIR2}/trace.bin

./dumptrace.exe ${DIR1}/trace.bin > trace-before.txt &
./dumptrace.exe ${DIR2}/trace.bin > trace-after.txt

