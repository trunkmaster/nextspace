#!/bin/bash

. /Developer/Makefiles/GNUstep.sh

export LDFLAGS="-Wl,-rpath,/usr/NextSpace/lib"

cd ./nextspace-base-1.27.0

make clean
./configure || exit 1

make $MAKE_ARGS install
