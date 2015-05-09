#!/bin/bash

make -j 12 emulator_test.exe || exit -1

echo " ******************************************************** "
echo " ** Please check in first, so that this is repeatable. ** "
echo " ******************************************************** "
echo ""
echo ""

REVISION=`svnversion`

echo "" >> comprehensive-log.txt
echo "Running comprehensive tests at SVN version " ${REVISION} >> comprehensive-log.txt
echo "Starting at" `date` >> comprehensive-log.txt
time ./emulator_test.exe --comprehensive || exit -1
echo -n " ... " ${REVISION} " Succeeded at " `date` >> comprehensive-log.txt
svn st
