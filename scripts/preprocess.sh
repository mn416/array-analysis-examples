#!/bin/bash

# Find files
FILES=`find * -name '*.F90'`

# List of files to ignore
IGNORE=""

# List of include directories for preprocessor to use
INC=`find *  -type d | xargs -i echo "-I {}" | xargs`

for FILE in $FILES; do
  BASE=$(basename $FILE .F90)
  DIR=$(dirname $FILE)
  FILE_PREFIX=$DIR/$BASE
  if [[ $IGNORE == *"$FILE_PREFIX"* ]]; then
    echo Ignoring $FILE_PREFIX
  else
    echo $FILE_PREFIX
    gfortran -cpp $INC -E -P $FILE_PREFIX.F90 -o /tmp/tmp.F90 2> /dev/null
    cp /tmp/tmp.F90 $FILE_PREFIX.F90
  fi
done
