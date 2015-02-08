#!/bin/sh

set +x

rm -f .sav ../fceulib2400/.sav
rm -f trace.bin ../fceulib2400/trace.bin
cp x6502.cc state.cc emulator_test.cc trace.{cc,h} tracing.{cc,h} ../fceulib2400/

cd ../fceulib2400
make -j 20 emulator_test.exe || exit -1 
./emulator_test.exe
cd ../fceulib_fixy
make -j 20 emulator_test.exe difftrace.exe || exit -1
./emulator_test.exe
./difftrace.exe ../fceulib2400/trace.bin trace.bin

