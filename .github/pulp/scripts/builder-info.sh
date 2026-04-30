#!/bin/bash

# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

OUTPUT=${PWD}/build-info.txt
OLD_PWD=${PWD}

# Print header
echo "Host: `hostname`" > $OUTPUT
echo "Date: `date`" >> $OUTPUT
echo "Kernel: `cat /proc/version`" >> $OUTPUT
echo "gcc: `gcc --version | head -n1`" >> $OUTPUT
echo "ld: `ld --version | head -n1`" >> $OUTPUT
echo "--- OS RELEASE ------------------" >> $OUTPUT
cat /etc/*-release >> $OUTPUT

echo "--- BUILD SOURCES ---------------" >> $OUTPUT
REPOS=$(find . -type d -name .git)
for dir in $REPOS; do
  cd $(dirname $OLD_PWD/$dir)
  if [ $PWD == $OLD_PWD ]; then
    echo -n "build-scripts: " >> $OUTPUT
  else
    echo -n "$(echo $PWD | sed "s#$OLD_PWD/##"): " >> $OUTPUT
  fi

  # Extract git commit and URL
  GITREV=$(git rev-parse HEAD)
  GITURL=$(git remote get-url origin)
  GITTAG=$(git describe --candidates=0 2>/dev/null)

  echo "${GITREV} (${GITURL}, tag: ${GITTAG})" >> $OUTPUT

done
