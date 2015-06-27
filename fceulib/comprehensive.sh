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


./emulator_test.exe --comprehensive --index 0 --modulus 10 || 
  echo "Revision ${REVISION} shard " 0 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 1 --modulus 10 || 
  echo "Revision ${REVISION} shard " 1 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 2 --modulus 10 || 
  echo "Revision ${REVISION} shard " 2 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 3 --modulus 10 || 
  echo "Revision ${REVISION} shard " 3 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 4 --modulus 10 || 
  echo "Revision ${REVISION} shard " 4 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 5 --modulus 10 || 
  echo "Revision ${REVISION} shard " 5 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 6 --modulus 10 || 
  echo "Revision ${REVISION} shard " 6 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 7 --modulus 10 || 
  echo "Revision ${REVISION} shard " 7 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 8 --modulus 10 || 
  echo "Revision ${REVISION} shard " 8 " FAILED" >> comprehensive-log.txt &
./emulator_test.exe --comprehensive --index 9 --modulus 10 || 
  echo "Revision ${REVISION} shard " 9 " FAILED" >> comprehensive-log.txt &

wait

echo -n " ... " ${REVISION} " Finished at " `date` >> comprehensive-log.txt
svn st
