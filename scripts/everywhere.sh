#!/bin/bash

# Apply the parallelisation to all .F90 files reachable from working dir.

# Find files
FILES=`find * -name '*.F90'`

# List of files to ignore
IGNORE=""

# List of include directories for PSyclone to search for imports
INC=""
#INC=`find *  -type d | xargs -i echo "-I {}" | xargs`

for FILE in $FILES; do
  OUT_PREFIX=$(echo $FILE | tr '/' '-' | xargs -i basename {} .F90)
  if [[ $IGNORE == *"$OUT_PREFIX"* ]]; then
    echo Ignoring $OUT_PREFIX
  else
    echo $OUT_PREFIX
    (time psyclone $INC -s /workspace/omp.py -o /dev/null $FILE) > $OUT_PREFIX.old 2> $OUT_PREFIX.old.err
    (time TIMEOUT=5000 USE_SMT=yes psyclone $INC -s /workspace/omp.py -o /dev/null $FILE) > $OUT_PREFIX.new 2> $OUT_PREFIX.new.err
    diff $OUT_PREFIX.old $OUT_PREFIX.new > $OUT_PREFIX.diff
    N1=$(grep conflict $OUT_PREFIX.old | wc -l)
    N2=$(grep conflict $OUT_PREFIX.new | wc -l)
    if [ ! "$N1" == "$N2" ]; then
      echo "ERROR $N1 $N2 $FILE" >> errors.txt
    fi
  fi
done

# Geomean analysis time overhead
grep real *.old.err | \
  cut -f 2| \
  awk -F 'm|s' '{ print ($1 * 60) + $2 }' > t_old.txt
grep real *.new.err | \
  cut -f 2 | \
  awk -F 'm|s' '{ print ($1 * 60) + $2 }' > t_new.txt
paste -d ' ' t_old.txt t_new.txt | \
  awk 'BEGIN{acc=1} {acc = acc * ($2/$1); n = n + 1} END{print acc^(1/n)}' \
    > analysis_time.txt
