#!/bin/bash

make -j 12 emulator_test.exe || exit -1

echo " ******************************************************** "
echo " ** Please check in first, so that this is repeatable. ** "
echo " ******************************************************** "
echo ""
echo ""

echo "" >> comprehensive-log.txt
echo -n "Running comprehensive tests at SVN version " >> comprehensive-log.txt
svnversion >> comprehensive-log.txt
echo -n "Starting at " >> comprehensive-log.txt
date >> comprehensive-log.txt
time ./emulator_test.exe --comprehensive || exit -1
echo -n " ... Succeeded at " >> comprehensive-log.txt
date >> comprehensive-log.txt
svn st
