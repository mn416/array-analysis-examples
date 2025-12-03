#!/bin/bash

# Find files
FILES=`find * -name '*.F90'`

# List of include directories for PSyclone to search for imports
#INC=""
INC=`find *  -type d | xargs -i echo "-I {}" | xargs`

for FILE in $FILES; do
  OUT_PREFIX=$(echo $FILE | tr '/' '-' | xargs -i basename {} .F90)
  echo $OUT_PREFIX
  (time USE_SMT=yes psyclone $INC -s /workspace/analyse.py -o /dev/null $FILE) 2> /dev/null > $OUT_PREFIX.out 
done
