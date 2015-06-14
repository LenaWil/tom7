#!/bin/bash

make -j 12 emulator_test.exe || exit -1

REVISION=`svnversion`

echo ""
if [[ ${REVISION} == *M* ]] 
then 
    echo " ******************************************************** "
    echo " ** Please check in first, so that this is repeatable. ** "
    echo " ******************************************************** "
    echo ""
    echo "Revision is ${REVISION} which looks modified."
    exit -1;
elif [[ ${REVISION} == *:* ]]
then
    echo " ******************************************************** "
    echo " ** Please update first, so that this is repeatable.   ** "
    echo " ******************************************************** "
    echo ""
    echo "Revision is ${REVISION} which looks like it has files"
    echo "from multiple different versions."
    exit -1;
else
    echo "Revision looks clean."
fi

echo "" >> comprehensive-log.txt
echo "Running comprehensive tests at SVN version " ${REVISION} >> comprehensive-log.txt
echo "Starting at" `date` >> comprehensive-log.txt
time ./emulator_test.exe --comprehensive || exit -1
echo -n " ... " ${REVISION} " Succeeded at " `date` >> comprehensive-log.txt
svn st
