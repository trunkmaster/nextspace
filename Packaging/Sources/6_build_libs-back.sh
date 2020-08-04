#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-back-${gnustep_back_version} || exit 1

$MAKE_CMD clean
./configure \
  --enable-graphics=art \
  --with-name=art

$MAKE_CMD fonts=no install
