#!/bin/bash

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-base-1.27.0 || exit 1

make clean
./configure || exit 1

make $MAKE_ARGS install
