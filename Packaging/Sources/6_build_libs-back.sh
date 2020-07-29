#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-back-${gnustep_back_version} || exit 1

make clean
./configure \
  --enable-graphics=art \
  --with-name=art

make fonts=no install
