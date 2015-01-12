#!/bin/sh

set +x

rm -f .sav ../fceulib2370/.sav
cp trace.{cc,h} tracing.{cc,h} ../fceulib2370/

cd ../fceulib2370
make -j 20 emulator_test.exe && ./emulator_test.exe || exit -1
cd ../fceulib
make -j 20 emulator_test.exe difftrace.exe && ./emulator_test.exe || exit -1
./difftrace.exe ../fceulib2370/trace.bin trace.bin
