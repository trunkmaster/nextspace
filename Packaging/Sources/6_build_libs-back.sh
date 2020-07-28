#!/bin/bash

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-back-0.28.0+nextspace || exit 1

make clean
./configure \
  --enable-graphics=art \
  --with-name=art

make fonts=no install
