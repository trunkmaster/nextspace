#!/bin/bash

. /Developer/Makefiles/GNUstep.sh

cd ./Frameworks || exit 1

make clean
make install
ldconfig
