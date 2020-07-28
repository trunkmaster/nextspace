#!/bin/bash

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-gui-0.28.0+nextspace || exit 1

make clean
sh ./configure

make install
